// Diagnóstico de Rede — App Android (Flutter)
// Visual espelhando o app web + Mapeamento com mapa de calor e bip-detector.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const DiagApp());

// Paleta (mesma do app web)
const kBg = Color(0xFF0B1020);
const kCard = Color(0xFF151C30);
const kCard2 = Color(0xFF1D2740);
const kLine = Color(0xFF2A3550);
const kTxt = Color(0xFFE6ECF7);
const kMuted = Color(0xFF8A9AC0);
const kAccent = Color(0xFF38BDF8);
const kAccent2 = Color(0xFF0EA5E9);
const kOk = Color(0xFF22C55E);
const kWarn = Color(0xFFF59E0B);
const kBad = Color(0xFFEF4444);

Color corSinal(int s) => s >= 75 ? kOk : (s >= 50 ? kAccent : (s >= 30 ? kWarn : kBad));

Color heatColor(int s) {
  final t = (s.clamp(0, 100)) / 100.0;
  if (t < .5) return Color.lerp(kBad, kWarn, t / .5)!;
  return Color.lerp(kWarn, kOk, (t - .5) / .5)!;
}

int rssiParaPorcento(int rssi) => (2 * (rssi + 100)).clamp(0, 100);

int? canalDaFrequencia(int f) {
  if (f >= 2412 && f <= 2484) return f == 2484 ? 14 : ((f - 2412) ~/ 5) + 1;
  if (f >= 5160 && f <= 5885) return (f - 5000) ~/ 5;
  return null;
}

String bandaDoCanal(int? c) => c == null ? '?' : (c <= 14 ? '2.4' : '5');

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
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

// Card padrão (igual ao .card do web)
class Secao extends StatelessWidget {
  final String titulo;
  final String? desc;
  final Widget filho;
  const Secao({super.key, required this.titulo, this.desc, required this.filho});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTxt)),
        if (desc != null) ...[
          const SizedBox(height: 4),
          Text(desc!, style: const TextStyle(fontSize: 13, color: kMuted)),
        ],
        const SizedBox(height: 14),
        filho,
      ]),
    );
  }
}

class BotaoRun extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final Color? cor;
  const BotaoRun(this.texto, {super.key, this.onTap, this.cor});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: cor ?? kAccent2,
          foregroundColor: const Color(0xFF041320),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        child: Text(texto),
      ),
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
  final _abas = const ['📋 Status', '📶 Canais', '📍 Mapa', '⚡ Velocidade', '🔐 Senha'];
  final _pages = const [StatusScreen(), CanaisScreen(), MapeamentoScreen(), VelocidadeScreen(), SenhaScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(children: const [
              Text('🛜', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Diagnóstico de Rede',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTxt)),
            ]),
          ),
          // Abas em pílula (iguais ao web)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: _abas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (c, i) {
                final sel = i == _idx;
                return GestureDetector(
                  onTap: () => setState(() => _idx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: sel ? const LinearGradient(colors: [kAccent, kAccent2]) : null,
                      color: sel ? null : kCard,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sel ? Colors.transparent : kLine),
                    ),
                    child: Text(_abas[i],
                        style: TextStyle(
                            color: sel ? const Color(0xFF041320) : kMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                );
              },
            ),
          ),
          Expanded(child: IndexedStack(index: _idx, children: _pages)),
        ]),
      ),
    );
  }
}

// ========================= STATUS =========================
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, String?> _d = {};
  bool _carregando = false;

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    await Permission.locationWhenInUse.request();
    final info = NetworkInfo();
    try {
      _d = {
        'Rede (SSID)': (await info.getWifiName())?.replaceAll('"', ''),
        'IP': await info.getWifiIP(),
        'Máscara': await info.getWifiSubmask(),
        'Gateway': await info.getWifiGatewayIP(),
        'MAC (BSSID)': await info.getWifiBSSID(),
      };
    } catch (e) {
      _d = {'Erro': '$e'};
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(
        titulo: '📋 Status da Rede',
        desc: 'Rede conectada, IP, máscara, gateway e MAC.',
        filho: Column(children: [
          if (_carregando) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          ..._d.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(e.key, style: const TextStyle(color: kMuted, fontSize: 13))),
                  Expanded(child: Text(e.value ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              )),
          const SizedBox(height: 12),
          BotaoRun('Atualizar', onTap: _carregando ? null : _carregar),
        ]),
      ),
    ]);
  }
}

// ========================= CANAIS =========================
class CanaisScreen extends StatefulWidget {
  const CanaisScreen({super.key});
  @override
  State<CanaisScreen> createState() => _CanaisScreenState();
}

class _CanaisScreenState extends State<CanaisScreen> {
  List<WiFiAccessPoint> _redes = [];
  String _msg = 'Toque em "Escanear" para ver os canais.';
  bool _scan = false;
  int? _m24, _m5;

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
    _redes = await WiFiScan.instance.getScannedResults();
    _calc();
    if (mounted) setState(() { _scan = false; _msg = _redes.isEmpty ? 'Nenhuma rede encontrada.' : ''; });
  }

  void _calc() {
    final r24 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '2.4');
    double p24(int c) => r24.fold(0.0, (a, r) {
          final ch = canalDaFrequencia(r.frequency)!;
          final d = (c - ch).abs();
          return a + (d == 0 ? 1.0 : (d < 5 ? (5 - d) / 5 : 0.0)) * rssiParaPorcento(r.level) / 100;
        });
    _m24 = r24.isEmpty ? null : [1, 6, 11].reduce((a, b) => p24(a) <= p24(b) ? a : b);

    final r5 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '5');
    final cand = {...r5.map((r) => canalDaFrequencia(r.frequency)!), 36, 40, 44, 48, 149, 153, 157, 161}.toList()..sort();
    double p5(int c) => r5.fold(0.0, (a, r) {
          final ch = canalDaFrequencia(r.frequency)!;
          final d = (c - ch).abs();
          return a + (ch == c ? 1.0 : (d <= 2 ? 0.3 : 0.0)) * rssiParaPorcento(r.level) / 100;
        });
    _m5 = r5.isEmpty ? null : cand.reduce((a, b) => p5(a) <= p5(b) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final ord = [..._redes]..sort((a, b) => b.level.compareTo(a.level));
    return ListView(children: [
      Secao(
        titulo: '📶 Canais Wi-Fi',
        desc: 'Redes vizinhas e o melhor canal (2.4 e 5 GHz).',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_m24 != null || _m5 != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_m24 != null) Text('✓ Melhor canal 2.4 GHz: $_m24', style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
                if (_m5 != null) Text('✓ Melhor canal 5 GHz: $_m5', style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(height: 10),
          if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: kMuted)),
          ...ord.map((r) {
            final ch = canalDaFrequencia(r.frequency);
            final s = rssiParaPorcento(r.level);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.ssid.isEmpty ? '(oculta)' : r.ssid, overflow: TextOverflow.ellipsis)),
                  Text('ch ${ch ?? "?"} • ${bandaDoCanal(ch)} GHz', style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: s / 100, minHeight: 10, backgroundColor: kCard2, color: corSinal(s)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 12),
          BotaoRun(_scan ? 'Escaneando...' : 'Escanear', onTap: _scan ? null : _escanear),
        ]),
      ),
    ]);
  }
}

// ========================= MAPEAMENTO (detector + mapa de calor + bip) =========================
class MapeamentoScreen extends StatefulWidget {
  const MapeamentoScreen({super.key});
  @override
  State<MapeamentoScreen> createState() => _MapeamentoScreenState();
}

class _MapeamentoScreenState extends State<MapeamentoScreen> {
  bool _rodando = false;
  bool _som = true;
  int _sinal = 0;
  int _max = 0;
  String? _bssid;
  final List<int> _hist = [];
  Timer? _amostraTimer;
  Timer? _bipTimer;
  int _tick = 0;

  Future<void> _iniciar() async {
    await Permission.locationWhenInUse.request();
    try { _bssid = await NetworkInfo().getWifiBSSID(); } catch (_) {}
    setState(() { _rodando = true; _hist.clear(); _max = 0; _tick = 0; });
    _amostraTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _amostrar());
    _amostrar();
  }

  void _parar() {
    _amostraTimer?.cancel();
    _bipTimer?.cancel();
    setState(() => _rodando = false);
  }

  Future<void> _amostrar() async {
    try {
      if (_tick % 3 == 0) {
        final can = await WiFiScan.instance.canStartScan();
        if (can == CanStartScan.yes) await WiFiScan.instance.startScan();
      }
      _tick++;
      final res = await WiFiScan.instance.getScannedResults();
      int? lvl;
      if (_bssid != null && _bssid!.isNotEmpty) {
        final m = res.where((r) => r.bssid.toLowerCase() == _bssid!.toLowerCase());
        if (m.isNotEmpty) lvl = m.first.level;
      }
      lvl ??= res.isEmpty ? null : res.map((r) => r.level).reduce(max);
      if (lvl != null) {
        final s = rssiParaPorcento(lvl);
        setState(() {
          _sinal = s;
          if (s > _max) _max = s;
          _hist.add(s);
          if (_hist.length > 90) _hist.removeAt(0);
        });
        _reagendarBip();
      }
    } catch (_) {}
  }

  void _reagendarBip() {
    _bipTimer?.cancel();
    if (!_rodando || !_som || _sinal <= 0) return;
    // Quanto mais forte o sinal, mais rápido o bip (120ms forte → 1000ms fraco)
    final intervalo = (1000 - _sinal * 8.5).clamp(120, 1000).toInt();
    _bipTimer = Timer.periodic(Duration(milliseconds: intervalo), (_) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    });
  }

  @override
  void dispose() {
    _amostraTimer?.cancel();
    _bipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = heatColor(_sinal);
    return ListView(children: [
      Secao(
        titulo: '📍 Mapa de Calor do Wi-Fi',
        desc: 'Ande pela casa com o som ligado: quanto mais forte o sinal, mais rápido o bip. Onde o bip ficar mais rápido é o melhor ponto.',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Leitura grande atual
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: kCard2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cor.withValues(alpha: .6), width: 2),
            ),
            child: Column(children: [
              Text('$_sinal%', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: cor, height: 1)),
              const SizedBox(height: 4),
              Text(_rodando ? 'medindo...' : 'parado', style: const TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Text('Melhor ponto encontrado: $_max%', style: const TextStyle(color: kTxt, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 14),
          // Mapa de calor (histórico da caminhada)
          const Text('Trilha (o mais recente fica à direita):', style: TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
            clipBehavior: Clip.antiAlias,
            child: _hist.isEmpty
                ? const Center(child: Text('sem dados ainda', style: TextStyle(color: kMuted, fontSize: 12)))
                : Row(children: _hist.map((s) => Expanded(child: Container(color: heatColor(s)))).toList()),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: BotaoRun(_rodando ? 'Parar' : 'Iniciar detecção',
                cor: _rodando ? kBad : kOk, onTap: _rodando ? _parar : _iniciar)),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => setState(() { _som = !_som; _reagendarBip(); }),
              icon: Icon(_som ? Icons.volume_up : Icons.volume_off),
              tooltip: _som ? 'Som ligado' : 'Som desligado',
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Dica: o bip usa o som e a vibração do sistema — deixe o volume e a vibração ligados. A atualização depende do Wi-Fi do aparelho (alguns Android limitam a frequência de varredura).',
              style: TextStyle(color: kMuted, fontSize: 11)),
        ]),
      ),
    ]);
  }
}

// ========================= VELOCIDADE =========================
class VelocidadeScreen extends StatefulWidget {
  const VelocidadeScreen({super.key});
  @override
  State<VelocidadeScreen> createState() => _VelocidadeScreenState();
}

class _VelocidadeScreenState extends State<VelocidadeScreen> {
  double _down = 0, _up = 0;
  int _ping = 0;
  String _status = 'Toque para testar.';
  bool _rodando = false;

  Future<void> _testar() async {
    setState(() { _rodando = true; _status = 'Medindo latência...'; _down = 0; _up = 0; _ping = 0; });
    try {
      int best = 1 << 30;
      for (int i = 0; i < 5; i++) {
        final t = DateTime.now();
        await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1000&r=$i'));
        best = min(best, DateTime.now().difference(t).inMilliseconds);
      }
      setState(() => _ping = best);
    } catch (_) {}
    setState(() => _status = 'Medindo download...');
    try {
      final t = DateTime.now();
      final r = await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=25000000'));
      final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
      setState(() => _down = (r.bodyBytes.length * 8) / seg / 1e6);
    } catch (_) {}
    setState(() => _status = 'Medindo upload...');
    try {
      final payload = Uint8List(10000000);
      final t = DateTime.now();
      await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload);
      final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
      setState(() => _up = (payload.length * 8) / seg / 1e6);
    } catch (_) {}
    setState(() { _rodando = false; _status = 'Concluído. Compare com o plano contratado.'; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(
        titulo: '⚡ Velocidade',
        desc: 'Download, upload e latência (servidor Cloudflare).',
        filho: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Gauge(valor: _down, label: 'Mbps ↓', cor: kAccent),
            _Gauge(valor: _up, label: 'Mbps ↑', cor: kOk),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(999)),
            child: Text('Latência: $_ping ms', style: const TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          Text(_status, style: const TextStyle(color: kMuted)),
          const SizedBox(height: 12),
          BotaoRun(_rodando ? 'Testando...' : 'Iniciar teste', onTap: _rodando ? null : _testar),
        ]),
      ),
    ]);
  }
}

class _Gauge extends StatelessWidget {
  final double valor;
  final String label;
  final Color cor;
  const _Gauge({required this.valor, required this.label, required this.cor});
  @override
  Widget build(BuildContext context) {
    final frac = valor <= 0 ? 0.0 : (log(valor + 1) / log(501)).clamp(0.0, 1.0);
    return Column(children: [
      SizedBox(
        width: 120, height: 120,
        child: CustomPaint(
          painter: _GaugePainter(frac, cor),
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(valor <= 0 ? '—' : valor.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTxt)),
              Text(label, style: const TextStyle(fontSize: 10, color: kMuted)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _GaugePainter extends CustomPainter {
  final double frac;
  final Color cor;
  _GaugePainter(this.frac, this.cor);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final fundo = Paint()..style = PaintingStyle.stroke..strokeWidth = 11..color = const Color(0xFF263253);
    canvas.drawCircle(c, r, fundo);
    final prog = Paint()..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round..color = cor;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * frac, false, prog);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.frac != frac || old.cor != cor;
}

// ========================= SENHA =========================
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
    final tm = RegExp(r'[a-z]').hasMatch(s), tM = RegExp(r'[A-Z]').hasMatch(s);
    final tn = RegExp(r'\d').hasMatch(s), ts = RegExp(r'[^\w]').hasMatch(s);
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
      Secao(
        titulo: '🔐 Força de senha',
        desc: 'Avaliação local — nada é enviado à rede.',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            obscureText: true,
            onChanged: _analisar,
            style: const TextStyle(color: kTxt),
            decoration: InputDecoration(
              hintText: 'Digite a senha', filled: true, fillColor: kCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: List.generate(5, (i) => Expanded(
                child: Container(
                  height: 9, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: i < _n ? _cor : kCard2, borderRadius: BorderRadius.circular(6)),
                ),
              ))),
          const SizedBox(height: 10),
          if (_nivel.isNotEmpty) Text(_nivel, style: TextStyle(color: _cor, fontWeight: FontWeight.bold)),
          Text(_info, style: const TextStyle(color: kMuted)),
        ]),
      ),
    ]);
  }
}
