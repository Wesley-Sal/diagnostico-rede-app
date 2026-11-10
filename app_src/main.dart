// Diagnóstico de Rede — App Android (Flutter)
// Esqueleto funcional: Status, Canais Wi-Fi, Velocidade e Senha.
// Plugins: wifi_scan, network_info_plus, permission_handler, http
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const DiagApp());

// Paleta (mesma do desktop)
const kBg = Color(0xFF0B1020);
const kCard = Color(0xFF151C30);
const kCard2 = Color(0xFF1D2740);
const kAccent = Color(0xFF38BDF8);
const kOk = Color(0xFF22C55E);
const kWarn = Color(0xFFF59E0B);
const kBad = Color(0xFFEF4444);

class DiagApp extends StatelessWidget {
  const DiagApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diagnóstico de Rede',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: kAccent,
        scaffoldBackgroundColor: kBg,
        cardColor: kCard,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;
  final _pages = const [StatusScreen(), CanaisScreen(), VelocidadeScreen(), SenhaScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛜  Diagnóstico de Rede'),
        backgroundColor: kCard,
      ),
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: kCard,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.wifi), label: 'Canais'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'Velocidade'),
          NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Senha'),
        ],
      ),
    );
  }
}

// Helpers compartilhados -----------------------------------------------------
int? canalDaFrequencia(int f) {
  if (f >= 2412 && f <= 2484) return f == 2484 ? 14 : ((f - 2412) ~/ 5) + 1;
  if (f >= 5160 && f <= 5885) return (f - 5000) ~/ 5;
  return null;
}

String bandaDoCanal(int? c) => c == null ? '?' : (c <= 14 ? '2.4' : '5');

int rssiParaPorcento(int rssi) => (2 * (rssi + 100)).clamp(0, 100);

Color corSinal(int s) => s >= 75 ? kOk : (s >= 50 ? kAccent : (s >= 30 ? kWarn : kBad));

Widget cartao({required String titulo, required Widget filho}) => Card(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          filho,
        ]),
      ),
    );

// 1) STATUS ------------------------------------------------------------------
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, String?> _dados = {};
  bool _carregando = false;

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    await Permission.locationWhenInUse.request();
    final info = NetworkInfo();
    try {
      _dados = {
        'Rede (SSID)': (await info.getWifiName())?.replaceAll('"', ''),
        'IP': await info.getWifiIP(),
        'Máscara': await info.getWifiSubmask(),
        'Gateway': await info.getWifiGatewayIP(),
        'MAC (BSSID)': await info.getWifiBSSID(),
      };
    } catch (e) {
      _dados = {'Erro': '$e'};
    }
    setState(() => _carregando = false);
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      cartao(
        titulo: '📋 Status da Rede',
        filho: Column(children: [
          if (_carregando) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          ..._dados.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(e.key, style: const TextStyle(color: Colors.white70))),
                  Expanded(child: Text(e.value ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              )),
          const SizedBox(height: 12),
          FilledButton(onPressed: _carregando ? null : _carregar, child: const Text('Atualizar')),
        ]),
      ),
    ]);
  }
}

// 2) CANAIS WI-FI ------------------------------------------------------------
class CanaisScreen extends StatefulWidget {
  const CanaisScreen({super.key});
  @override
  State<CanaisScreen> createState() => _CanaisScreenState();
}

class _CanaisScreenState extends State<CanaisScreen> {
  List<WiFiAccessPoint> _redes = [];
  String _msg = 'Toque em "Escanear" para ver os canais.';
  bool _scan = false;
  int? _melhor24, _melhor5;

  Future<void> _escanear() async {
    setState(() { _scan = true; _msg = 'Escaneando...'; });
    await Permission.locationWhenInUse.request();
    final can = await WiFiScan.instance.canStartScan();
    if (can != CanStartScan.yes) {
      setState(() { _scan = false; _msg = 'Não foi possível escanear: $can'; });
      return;
    }
    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(seconds: 3));
    final res = await WiFiScan.instance.getScannedResults();
    _redes = res;
    _calcularMelhores();
    setState(() { _scan = false; _msg = _redes.isEmpty ? 'Nenhuma rede encontrada.' : ''; });
  }

  void _calcularMelhores() {
    List<int> cDe(String banda) => _redes
        .map((r) => canalDaFrequencia(r.frequency))
        .whereType<int>()
        .where((c) => bandaDoCanal(c) == banda)
        .toList();

    // 2.4 GHz: melhor entre 1,6,11
    final r24 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '2.4');
    double pen24(int c) => r24.fold(0.0, (acc, r) {
          final ch = canalDaFrequencia(r.frequency)!;
          final d = (c - ch).abs();
          final fator = d == 0 ? 1.0 : (d < 5 ? (5 - d) / 5 : 0.0);
          return acc + fator * (rssiParaPorcento(r.level) / 100);
        });
    _melhor24 = r24.isEmpty ? null : [1, 6, 11].reduce((a, b) => pen24(a) <= pen24(b) ? a : b);

    // 5 GHz: melhor entre os presentes + padrão
    final r5 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '5');
    final cand = {...cDe('5'), 36, 40, 44, 48, 149, 153, 157, 161}.toList()..sort();
    double pen5(int c) => r5.fold(0.0, (acc, r) {
          final ch = canalDaFrequencia(r.frequency)!;
          final d = (c - ch).abs();
          final fator = ch == c ? 1.0 : (d <= 2 ? 0.3 : 0.0);
          return acc + fator * (rssiParaPorcento(r.level) / 100);
        });
    _melhor5 = r5.isEmpty ? null : cand.reduce((a, b) => pen5(a) <= pen5(b) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final ordenadas = [..._redes]..sort((a, b) => b.level.compareTo(a.level));
    return ListView(children: [
      cartao(
        titulo: '📶 Canais Wi-Fi',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_melhor24 != null || _melhor5 != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_melhor24 != null) Text('✓ Melhor canal 2.4 GHz: $_melhor24',
                    style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
                if (_melhor5 != null) Text('✓ Melhor canal 5 GHz: $_melhor5',
                    style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(height: 10),
          if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: Colors.white70)),
          ...ordenadas.map((r) {
            final ch = canalDaFrequencia(r.frequency);
            final s = rssiParaPorcento(r.level);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.ssid.isEmpty ? '(oculta)' : r.ssid,
                      overflow: TextOverflow.ellipsis)),
                  Text('ch ${ch ?? "?"} • ${bandaDoCanal(ch)} GHz',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: s / 100, minHeight: 10,
                    backgroundColor: kCard2, color: corSinal(s)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 12),
          FilledButton(onPressed: _scan ? null : _escanear,
              child: Text(_scan ? 'Escaneando...' : 'Escanear')),
        ]),
      ),
    ]);
  }
}

// 3) VELOCIDADE --------------------------------------------------------------
class VelocidadeScreen extends StatefulWidget {
  const VelocidadeScreen({super.key});
  @override
  State<VelocidadeScreen> createState() => _VelocidadeScreenState();
}

class _VelocidadeScreenState extends State<VelocidadeScreen> {
  String _down = '—', _up = '—', _ping = '—', _status = 'Toque para testar.';
  bool _rodando = false;

  Future<void> _testar() async {
    setState(() { _rodando = true; _status = 'Medindo latência...'; });
    // latência
    try {
      int best = 1 << 30;
      for (int i = 0; i < 5; i++) {
        final t = DateTime.now();
        await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1000&r=$i'));
        best = min(best, DateTime.now().difference(t).inMilliseconds);
      }
      _ping = '$best';
    } catch (_) {}
    // download ~25MB
    setState(() => _status = 'Medindo download...');
    try {
      final t = DateTime.now();
      final r = await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=25000000'));
      final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
      _down = ((r.bodyBytes.length * 8) / seg / 1e6).toStringAsFixed(1);
    } catch (_) {}
    // upload ~10MB
    setState(() => _status = 'Medindo upload...');
    try {
      final payload = Uint8List(10000000);
      final t = DateTime.now();
      await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload);
      final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
      _up = ((payload.length * 8) / seg / 1e6).toStringAsFixed(1);
    } catch (_) {}
    setState(() { _rodando = false; _status = 'Concluído. Compare com o plano contratado.'; });
  }

  Widget _metric(String v, String l, Color c) => Column(children: [
        Text(v, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c)),
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      cartao(
        titulo: '⚡ Velocidade',
        filho: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _metric(_down, 'Mbps ↓', kAccent),
            _metric(_up, 'Mbps ↑', kOk),
            _metric(_ping, 'ms', Colors.white),
          ]),
          const SizedBox(height: 14),
          Text(_status, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _rodando ? null : _testar,
              child: Text(_rodando ? 'Testando...' : 'Iniciar teste')),
        ]),
      ),
    ]);
  }
}

// 4) SENHA -------------------------------------------------------------------
class SenhaScreen extends StatefulWidget {
  const SenhaScreen({super.key});
  @override
  State<SenhaScreen> createState() => _SenhaScreenState();
}

class _SenhaScreenState extends State<SenhaScreen> {
  String _nivel = '', _info = '';
  int _n = 0;
  Color _cor = kCard2;

  void _analisar(String s) {
    if (s.isEmpty) { setState(() { _nivel = ''; _info = ''; _n = 0; }); return; }
    final tm = RegExp(r'[a-z]').hasMatch(s);
    final tM = RegExp(r'[A-Z]').hasMatch(s);
    final tn = RegExp(r'\d').hasMatch(s);
    final ts = RegExp(r'[^\w]').hasMatch(s);
    int esp = (tm ? 26 : 0) + (tM ? 26 : 0) + (tn ? 10 : 0) + (ts ? 33 : 0);
    if (esp == 0) esp = 1;
    final bits = s.length * (log(esp) / log(2));
    if (bits < 28) { _nivel = 'MUITO FRACA'; _n = 1; _cor = kBad; }
    else if (bits < 40) { _nivel = 'FRACA'; _n = 2; _cor = kWarn; }
    else if (bits < 60) { _nivel = 'RAZOÁVEL'; _n = 3; _cor = kWarn; }
    else if (bits < 80) { _nivel = 'FORTE'; _n = 4; _cor = kOk; }
    else { _nivel = 'MUITO FORTE'; _n = 5; _cor = kOk; }
    _info = '${s.length} caracteres • ${bits.toStringAsFixed(0)} bits';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      cartao(
        titulo: '🔐 Força de senha',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            obscureText: true,
            onChanged: _analisar,
            decoration: const InputDecoration(
              hintText: 'Digite a senha', filled: true, fillColor: kCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: List.generate(5, (i) => Expanded(
                child: Container(
                  height: 9, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i < _n ? _cor : kCard2, borderRadius: BorderRadius.circular(6)),
                ),
              ))),
          const SizedBox(height: 10),
          if (_nivel.isNotEmpty)
            Text(_nivel, style: TextStyle(color: _cor, fontWeight: FontWeight.bold)),
          Text(_info, style: const TextStyle(color: Colors.white54)),
        ]),
      ),
    ]);
  }
}
