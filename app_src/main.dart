// Diagnóstico de Rede — App Android (Flutter)
// Abas: Status, Canais, Conexão (ping/tracert), DNS, Mapa (cômodos+bip), Velocidade (servidores), Senha
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

void main() => runApp(const DiagApp());

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
      ),
      home: const HomePage(),
    );
  }
}

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
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTxt)),
        if (desc != null) ...[const SizedBox(height: 4), Text(desc!, style: const TextStyle(fontSize: 13, color: kMuted))],
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
          backgroundColor: cor ?? kAccent2, foregroundColor: const Color(0xFF041320),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        child: Text(texto),
      ),
    );
  }
}

InputDecoration campoDeco(String hint) => InputDecoration(
      hintText: hint, filled: true, fillColor: kCard2, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );

Widget saidaMono(String texto) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF080D1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
      child: Text(texto, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFB8C4E0))),
    );

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;
  final _abas = const ['🔎 Geral', '📋 Status', '📶 Canais', '🔌 Conexão', '🌐 DNS', '📍 Mapa', '⚡ Velocidade', '🔐 Senha'];
  final _pages = const [TesteGeralScreen(), StatusScreen(), CanaisScreen(), ConexaoScreen(), DnsScreen(), MapaScreen(), VelocidadeScreen(), SenhaScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(children: const [
              Text('🛜', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Diagnóstico de Rede', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTxt)),
            ]),
          ),
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
                    child: Text(_abas[i], style: TextStyle(color: sel ? const Color(0xFF041320) : kMuted, fontWeight: FontWeight.w600, fontSize: 13)),
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

// ========================= TESTE GERAL + RELATÓRIO =========================
class TesteGeralScreen extends StatefulWidget {
  const TesteGeralScreen({super.key});
  @override
  State<TesteGeralScreen> createState() => _TesteGeralScreenState();
}
class _TesteGeralScreenState extends State<TesteGeralScreen> {
  bool _rodando = false;
  String _status = '';
  String _relatorio = '';

  Future<String> _secStatus() async {
    final info = NetworkInfo();
    try {
      final ssid = (await info.getWifiName())?.replaceAll('"', '') ?? '—';
      final ip = await info.getWifiIP() ?? '—';
      final mask = await info.getWifiSubmask() ?? '—';
      final gw = await info.getWifiGatewayIP() ?? '—';
      return 'SSID: $ssid\nIP: $ip\nMáscara: $mask\nGateway: $gw';
    } catch (e) { return 'erro: $e'; }
  }

  Future<String> _secPing() async {
    try {
      final r = await Process.run('ping', ['-c', '4', '8.8.8.8']).timeout(const Duration(seconds: 30));
      final out = r.stdout.toString();
      final tempos = RegExp(r'time=([\d.]+)').allMatches(out).map((m) => double.parse(m.group(1)!)).toList();
      final perda = RegExp(r'(\d+)% packet loss').firstMatch(out)?.group(1) ?? '?';
      if (tempos.isEmpty) return 'Sem resposta (perda $perda%).';
      final media = tempos.reduce((a, b) => a + b) / tempos.length;
      return 'Latência média: ${media.toStringAsFixed(0)} ms | perda: $perda%';
    } catch (e) { return 'erro: $e'; }
  }

  Future<String> _secCanais() async {
    try {
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) { await WiFiScan.instance.startScan(); await Future.delayed(const Duration(seconds: 3)); }
      final redes = await WiFiScan.instance.getScannedResults();
      if (redes.isEmpty) return 'nenhuma rede detectada';
      final r24 = redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '2.4');
      final r5 = redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '5');
      double p24(int c) => r24.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (d == 0 ? 1.0 : (d < 5 ? (5 - d) / 5 : 0.0)) * rssiParaPorcento(r.level) / 100; });
      final m24 = r24.isEmpty ? '—' : '${[1, 6, 11].reduce((a, b) => p24(a) <= p24(b) ? a : b)}';
      final cand = {...r5.map((r) => canalDaFrequencia(r.frequency)!), 36, 40, 44, 48, 149, 153, 157, 161}.toList()..sort();
      double p5(int c) => r5.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (ch == c ? 1.0 : (d <= 2 ? 0.3 : 0.0)) * rssiParaPorcento(r.level) / 100; });
      final m5 = r5.isEmpty ? '—' : '${cand.reduce((a, b) => p5(a) <= p5(b) ? a : b)}';
      return 'Redes: ${redes.length} | Melhor 2.4 GHz: $m24 | Melhor 5 GHz: $m5';
    } catch (e) { return 'erro: $e'; }
  }

  Future<String> _secDns() async {
    final linhas = <String>[];
    try {
      final t = DateTime.now();
      final a = await InternetAddress.lookup('google.com');
      linhas.add('Operadora: ${DateTime.now().difference(t).inMilliseconds} ms (${a.first.address})');
    } catch (_) { linhas.add('Operadora: falhou'); }
    for (final p in [['Google', 'https://dns.google/resolve?name=google.com&type=A', <String, String>{}], ['Cloudflare', 'https://cloudflare-dns.com/dns-query?name=google.com&type=A', {'Accept': 'application/dns-json'}]]) {
      try {
        final t = DateTime.now();
        await http.get(Uri.parse(p[1] as String), headers: p[2] as Map<String, String>).timeout(const Duration(seconds: 8));
        linhas.add('${p[0]}: ${DateTime.now().difference(t).inMilliseconds} ms');
      } catch (_) { linhas.add('${p[0]}: erro'); }
    }
    return linhas.join('\n');
  }

  Future<String> _secVel() async {
    int ping = 0;
    double down = 0;
    try {
      final t = DateTime.now();
      final s = await Socket.connect('speed.cloudflare.com', 443, timeout: const Duration(seconds: 4));
      s.destroy();
      ping = DateTime.now().difference(t).inMilliseconds;
    } catch (_) {}
    try {
      final client = http.Client();
      final resp = await client.send(http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=25000000')));
      final inicio = DateTime.now();
      int total = 0;
      await for (final c in resp.stream) { total += c.length; if (total >= 20000000 || DateTime.now().difference(inicio).inSeconds >= 12) break; }
      client.close();
      final seg = DateTime.now().difference(inicio).inMilliseconds / 1000.0;
      if (seg > 0) down = (total * 8) / seg / 1e6;
    } catch (_) {}
    return 'Download: ${down.toStringAsFixed(1)} Mbps | Latência: $ping ms (servidor Cloudflare)';
  }

  Future<void> _rodar() async {
    setState(() { _rodando = true; _relatorio = ''; });
    final sb = StringBuffer();
    final bar = '=' * 44;
    sb.writeln(bar);
    sb.writeln(' RELATÓRIO DE REDE');
    sb.writeln(' Data: ${DateTime.now().toString().substring(0, 19)}');
    sb.writeln(bar);
    setState(() => _status = 'Coletando status...');
    sb.writeln('\n[1] STATUS\n${await _secStatus()}');
    setState(() => _status = 'Testando conexão (ping)...');
    sb.writeln('\n[2] CONEXÃO\n${await _secPing()}');
    setState(() => _status = 'Escaneando canais...');
    sb.writeln('\n[3] CANAIS WI-FI\n${await _secCanais()}');
    setState(() => _status = 'Testando DNS...');
    sb.writeln('\n[4] DNS\n${await _secDns()}');
    setState(() => _status = 'Medindo velocidade...');
    sb.writeln('\n[5] VELOCIDADE\n${await _secVel()}');
    sb.writeln('\n$bar');
    if (mounted) setState(() { _rodando = false; _status = 'Concluído.'; _relatorio = sb.toString(); });
  }

  Future<void> _compartilharTxt() async {
    if (_relatorio.isEmpty) return;
    await Share.share(_relatorio, subject: 'Relatório de Rede');
  }

  Future<void> _gerarPdf() async {
    if (_relatorio.isEmpty) return;
    await Printing.layoutPdf(onLayout: (format) async {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(build: (c) => [
            pw.Header(level: 0, text: 'Relatório de Rede'),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _relatorio.split('\n').map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 10))).toList()),
          ]));
      return doc.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🔎 Teste Geral', desc: 'Roda todos os testes e gera um relatório pronto pra compartilhar ou salvar em PDF.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BotaoRun(_rodando ? 'Rodando...' : 'Rodar teste geral', onTap: _rodando ? null : _rodar),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          if (_rodando) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(_status, style: const TextStyle(color: kMuted)),
        ])),
        if (_relatorio.isNotEmpty) ...[
          saidaMono(_relatorio),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BotaoRun('Compartilhar TXT', cor: kOk, onTap: _compartilharTxt)),
            const SizedBox(width: 10),
            Expanded(child: BotaoRun('Gerar PDF', cor: kBad, onTap: _gerarPdf)),
          ]),
        ],
      ])),
    ]);
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
  bool _c = false;
  Future<void> _carregar() async {
    setState(() => _c = true);
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
    } catch (e) { _d = {'Erro': '$e'}; }
    if (mounted) setState(() => _c = false);
  }
  @override
  void initState() { super.initState(); _carregar(); }
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '📋 Status da Rede', desc: 'Rede conectada, IP, máscara, gateway e MAC.', filho: Column(children: [
        if (_c) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        ..._d.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          SizedBox(width: 120, child: Text(e.key, style: const TextStyle(color: kMuted, fontSize: 13))),
          Expanded(child: Text(e.value ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]))),
        const SizedBox(height: 12),
        BotaoRun('Atualizar', onTap: _c ? null : _carregar),
      ])),
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
    if (can != CanStartScan.yes) { setState(() { _scan = false; _msg = 'Não foi possível escanear: $can'; }); return; }
    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(seconds: 3));
    _redes = await WiFiScan.instance.getScannedResults();
    _calc();
    if (mounted) setState(() { _scan = false; _msg = _redes.isEmpty ? 'Nenhuma rede encontrada.' : ''; });
  }
  void _calc() {
    final r24 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '2.4');
    double p24(int c) => r24.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (d == 0 ? 1.0 : (d < 5 ? (5 - d) / 5 : 0.0)) * rssiParaPorcento(r.level) / 100; });
    _m24 = r24.isEmpty ? null : [1, 6, 11].reduce((a, b) => p24(a) <= p24(b) ? a : b);
    final r5 = _redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == '5');
    final cand = {...r5.map((r) => canalDaFrequencia(r.frequency)!), 36, 40, 44, 48, 149, 153, 157, 161}.toList()..sort();
    double p5(int c) => r5.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (ch == c ? 1.0 : (d <= 2 ? 0.3 : 0.0)) * rssiParaPorcento(r.level) / 100; });
    _m5 = r5.isEmpty ? null : cand.reduce((a, b) => p5(a) <= p5(b) ? a : b);
  }
  @override
  Widget build(BuildContext context) {
    final ord = [..._redes]..sort((a, b) => b.level.compareTo(a.level));
    return ListView(children: [
      Secao(titulo: '📶 Canais Wi-Fi', desc: 'Redes vizinhas e o melhor canal (2.4 e 5 GHz).', filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_m24 != null || _m5 != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_m24 != null) Text('✓ Melhor canal 2.4 GHz: $_m24', style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
          if (_m5 != null) Text('✓ Melhor canal 5 GHz: $_m5', style: const TextStyle(color: kOk, fontWeight: FontWeight.bold)),
        ])),
        const SizedBox(height: 10),
        if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: kMuted)),
        ...ord.map((r) {
          final ch = canalDaFrequencia(r.frequency);
          final s = rssiParaPorcento(r.level);
          return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.ssid.isEmpty ? '(oculta)' : r.ssid, overflow: TextOverflow.ellipsis)),
              Text('ch ${ch ?? "?"} • ${bandaDoCanal(ch)} GHz', style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: s / 100, minHeight: 10, backgroundColor: kCard2, color: corSinal(s))),
          ]));
        }),
        const SizedBox(height: 12),
        BotaoRun(_scan ? 'Escaneando...' : 'Escanear', onTap: _scan ? null : _escanear),
      ])),
    ]);
  }
}

// ========================= CONEXÃO (ping + traceroute) =========================
class ConexaoScreen extends StatefulWidget {
  const ConexaoScreen({super.key});
  @override
  State<ConexaoScreen> createState() => _ConexaoScreenState();
}
class _ConexaoScreenState extends State<ConexaoScreen> {
  final _host = TextEditingController(text: '8.8.8.8');
  final _n = TextEditingController(text: '4');
  final _size = TextEditingController(text: '');
  String _out = 'Informe o destino, ajuste se quiser e teste.';
  bool _rodando = false;

  Future<String> _ping() async {
    final n = int.tryParse(_n.text) ?? 4;
    final size = int.tryParse(_size.text);
    final args = ['-c', '${n.clamp(1, 50)}'];
    if (size != null && size > 0) args.addAll(['-s', '$size']);
    args.add(_host.text.trim());
    try {
      final r = await Process.run('ping', args).timeout(Duration(seconds: n * 3 + 20));
      return (r.stdout.toString() + r.stderr.toString()).trim();
    } catch (e) { return 'Erro ao executar ping: $e'; }
  }

  Future<String> _tracert() async {
    for (final bin in ['traceroute', '/system/bin/traceroute']) {
      try {
        final r = await Process.run(bin, ['-n', '-m', '20', _host.text.trim()]).timeout(const Duration(seconds: 60));
        final out = (r.stdout.toString() + r.stderr.toString()).trim();
        if (out.isNotEmpty && !out.toLowerCase().contains('not found')) return out;
      } catch (_) {}
    }
    return 'Traceroute não está disponível neste Android (normalmente exige root). O ping acima já indica se o destino responde e a latência.';
  }

  Future<void> _testar({bool tracert = false}) async {
    setState(() { _rodando = true; _out = 'Executando...'; });
    final size = _size.text.trim();
    final cab = 'Destino: ${_host.text.trim()} (${_n.text} pacotes${size.isNotEmpty ? ", $size bytes" : ""})\n';
    var txt = '$cab\n>>> PING\n${await _ping()}';
    if (tracert) txt += '\n\n>>> TRACEROUTE\n${await _tracert()}';
    if (mounted) setState(() { _rodando = false; _out = txt; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🔌 Conexão', desc: 'Ping com repetições e tamanho do pacote, e traceroute.', filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _host, style: const TextStyle(color: kTxt), decoration: campoDeco('destino (IP ou site)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Repetições', style: TextStyle(color: kMuted, fontSize: 12)),
            TextField(controller: _n, keyboardType: TextInputType.number, style: const TextStyle(color: kTxt), decoration: campoDeco('4')),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tamanho (bytes)', style: TextStyle(color: kMuted, fontSize: 12)),
            TextField(controller: _size, keyboardType: TextInputType.number, style: const TextStyle(color: kTxt), decoration: campoDeco('padrão')),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: BotaoRun(_rodando ? '...' : 'Ping', onTap: _rodando ? null : () => _testar())),
          const SizedBox(width: 10),
          Expanded(child: BotaoRun('Ping + Tracert', cor: kCard2, onTap: _rodando ? null : () => _testar(tracert: true))),
        ]),
        saidaMono(_out),
      ])),
    ]);
  }
}

// ========================= DNS =========================
class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});
  @override
  State<DnsScreen> createState() => _DnsScreenState();
}
class _DnsScreenState extends State<DnsScreen> {
  final _host = TextEditingController(text: 'google.com');
  List<Map<String, dynamic>> _itens = [];
  bool _rodando = false;
  String _nota = '';

  Future<Map<String, dynamic>> _doh(String nome, String url, Map<String, String> h) async {
    try {
      final t = DateTime.now();
      final r = await http.get(Uri.parse(url), headers: h).timeout(const Duration(seconds: 8));
      final ms = DateTime.now().difference(t).inMilliseconds;
      final d = jsonDecode(r.body);
      final ans = (d['Answer'] as List?)?.where((a) => a['type'] == 1).map((a) => a['data']).toList() ?? [];
      return {'nome': nome, 'ms': ms, 'ip': ans.isNotEmpty ? ans.first : 'sem registro A'};
    } catch (_) { return {'nome': nome, 'ms': null, 'ip': 'erro'}; }
  }

  Future<void> _testar() async {
    final dom = _host.text.trim().isEmpty ? 'google.com' : _host.text.trim();
    setState(() { _rodando = true; _itens = []; _nota = ''; });
    final res = <Map<String, dynamic>>[];
    // Operadora (resolver do sistema)
    try {
      final t = DateTime.now();
      final addrs = await InternetAddress.lookup(dom);
      final ms = DateTime.now().difference(t).inMilliseconds;
      final ipv4 = addrs.firstWhere((a) => a.type == InternetAddressType.IPv4, orElse: () => addrs.first).address;
      res.add({'nome': 'Operadora (sistema)', 'ms': ms, 'ip': ipv4});
    } catch (_) { res.add({'nome': 'Operadora (sistema)', 'ms': null, 'ip': 'falhou'}); }
    res.add(await _doh('Google 8.8.8.8', 'https://dns.google/resolve?name=$dom&type=A', {}));
    res.add(await _doh('Cloudflare 1.1.1.1', 'https://cloudflare-dns.com/dns-query?name=$dom&type=A', {'Accept': 'application/dns-json'}));
    final ok = res.where((x) => x['ms'] != null).toList();
    if (ok.isNotEmpty) {
      ok.sort((a, b) => (a['ms'] as int).compareTo(b['ms'] as int));
      _nota = 'Mais rápido: ${ok.first['nome']} (${ok.first['ms']} ms). Se a Operadora for bem mais lenta, vale trocar o DNS no roteador.';
    }
    if (mounted) setState(() { _rodando = false; _itens = res; });
  }

  @override
  Widget build(BuildContext context) {
    final cores = [const Color(0xFF8B5CF6), const Color(0xFF4285F4), const Color(0xFFF6821F)];
    final ms = _itens.where((x) => x['ms'] != null).map((x) => x['ms'] as int);
    final mx = ms.isEmpty ? 1 : ms.reduce(max);
    return ListView(children: [
      Secao(titulo: '🌐 DNS', desc: 'Compara a Operadora (seu provedor), Google e Cloudflare.', filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _host, style: const TextStyle(color: kTxt), decoration: campoDeco('domínio (ex: google.com)')),
        const SizedBox(height: 12),
        BotaoRun(_rodando ? 'Consultando...' : 'Testar DNS', onTap: _rodando ? null : _testar),
        const SizedBox(height: 14),
        ..._itens.asMap().entries.map((e) {
          final x = e.value;
          final cor = cores[e.key % cores.length];
          final larg = x['ms'] != null ? max(0.12, (x['ms'] as int) / mx) : 0.0;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(x['nome'])), Text('${x['ip']}', style: const TextStyle(color: kMuted, fontSize: 12))]),
            const SizedBox(height: 4),
            Stack(children: [
              Container(height: 16, decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(999))),
              FractionallySizedBox(widthFactor: larg.toDouble(), child: Container(height: 16, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(999)),
                  child: Text(x['ms'] != null ? '${x['ms']} ms' : 'falhou', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF041320))))),
            ]),
          ]));
        }),
        if (_nota.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_nota, style: const TextStyle(color: kMuted, fontSize: 12))),
      ])),
    ]);
  }
}

// ========================= MAPA (cômodos + bip) =========================
class _Comodo { String nome; int? sinal; _Comodo(this.nome, [this.sinal]); }

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}
class _MapaScreenState extends State<MapaScreen> {
  final List<_Comodo> _comodos = [];
  bool _detector = false, _som = true;
  int _sinal = 0;
  String? _bssid;
  Timer? _amostra, _bip;
  int _tick = 0;

  Future<int?> _lerSinal() async {
    try {
      if (_tick % 3 == 0) { final can = await WiFiScan.instance.canStartScan(); if (can == CanStartScan.yes) await WiFiScan.instance.startScan(); }
      _tick++;
      final res = await WiFiScan.instance.getScannedResults();
      int? lvl;
      if (_bssid != null && _bssid!.isNotEmpty) { final m = res.where((r) => r.bssid.toLowerCase() == _bssid!.toLowerCase()); if (m.isNotEmpty) lvl = m.first.level; }
      lvl ??= res.isEmpty ? null : res.map((r) => r.level).reduce(max);
      return lvl == null ? null : rssiParaPorcento(lvl);
    } catch (_) { return null; }
  }

  Future<void> _ligarDetector() async {
    await Permission.locationWhenInUse.request();
    try { _bssid = await NetworkInfo().getWifiBSSID(); } catch (_) {}
    setState(() { _detector = true; _tick = 0; });
    _amostra = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      final s = await _lerSinal();
      if (s != null) { setState(() => _sinal = s); _reBip(); }
    });
  }
  void _desligarDetector() { _amostra?.cancel(); _bip?.cancel(); setState(() => _detector = false); }
  void _reBip() {
    _bip?.cancel();
    if (!_detector || !_som || _sinal <= 0) return;
    final intervalo = (1000 - _sinal * 8.5).clamp(120, 1000).toInt();
    _bip = Timer.periodic(Duration(milliseconds: intervalo), (_) { SystemSound.play(SystemSoundType.click); HapticFeedback.selectionClick(); });
  }

  Future<void> _medir(_Comodo c) async {
    await Permission.locationWhenInUse.request();
    if (_bssid == null) { try { _bssid = await NetworkInfo().getWifiBSSID(); } catch (_) {} }
    final s = _detector ? _sinal : await _lerSinal();
    if (s != null) setState(() => c.sinal = s);
  }

  void _novoComodo() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('Novo cômodo', style: TextStyle(color: kTxt)),
      content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: kTxt), decoration: campoDeco('ex: Sala, Quarto, Cozinha')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () { final nome = ctrl.text.trim(); Navigator.pop(ctx); setState(() => _comodos.add(_Comodo(nome.isEmpty ? 'Cômodo ${_comodos.length + 1}' : nome))); }, child: const Text('Adicionar')),
      ],
    ));
  }

  @override
  void dispose() { _amostra?.cancel(); _bip?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final medidos = _comodos.where((c) => c.sinal != null).toList();
    _Comodo? melhor, pior;
    if (medidos.isNotEmpty) {
      melhor = medidos.reduce((a, b) => a.sinal! >= b.sinal! ? a : b);
      pior = medidos.reduce((a, b) => a.sinal! <= b.sinal! ? a : b);
    }
    final cor = heatColor(_sinal);
    return ListView(children: [
      Secao(titulo: '📍 Mapa de Sinal por Cômodo', desc: 'Cadastre os cômodos e meça o sinal em cada um. Ligue o detector pra achar o melhor ponto "de ouvido" (o bip acelera quando o sinal é mais forte).', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Detector ao vivo
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(14), border: Border.all(color: cor.withValues(alpha: .6), width: 2)),
          child: Column(children: [
            Text('$_sinal%', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: cor, height: 1)),
            Text(_detector ? 'detector ligado' : 'detector desligado', style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: BotaoRun(_detector ? 'Parar detector' : 'Ligar detector', cor: _detector ? kBad : kAccent2, onTap: _detector ? _desligarDetector : _ligarDetector)),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: () => setState(() { _som = !_som; _reBip(); }), icon: Icon(_som ? Icons.volume_up : Icons.volume_off)),
        ]),
        const Divider(height: 28, color: kLine),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Cômodos', style: TextStyle(fontWeight: FontWeight.bold, color: kTxt)),
          TextButton.icon(onPressed: _novoComodo, icon: const Icon(Icons.add, size: 18), label: const Text('Cômodo')),
        ]),
        if (_comodos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum cômodo ainda. Toque em "Cômodo" para adicionar.', style: TextStyle(color: kMuted, fontSize: 13))),
        ..._comodos.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (c.sinal ?? 0) / 100, minHeight: 10, backgroundColor: kCard2, color: c.sinal == null ? kCard2 : heatColor(c.sinal!))),
          ])),
          const SizedBox(width: 10),
          SizedBox(width: 48, child: Text(c.sinal == null ? '—' : '${c.sinal}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: c.sinal == null ? kMuted : heatColor(c.sinal!)))),
          IconButton(onPressed: () => _medir(c), icon: const Icon(Icons.wifi_find, color: kAccent), tooltip: 'Medir aqui'),
          IconButton(onPressed: () => setState(() => _comodos.remove(c)), icon: const Icon(Icons.close, color: kMuted, size: 18)),
        ]))),
        if (melhor != null) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)), child: Text(
          '🏠 Melhor ponto: ${melhor.nome} (${melhor.sinal}%)' + (pior != null && pior.sinal! < 40 ? '\n⚠ Pior: ${pior.nome} (${pior.sinal}%) — considere um repetidor/mesh aqui.' : ''),
          style: const TextStyle(color: kTxt, fontSize: 13))),
      ])),
    ]);
  }
}

// ========================= VELOCIDADE (com servidores) =========================
class VelocidadeScreen extends StatefulWidget {
  const VelocidadeScreen({super.key});
  @override
  State<VelocidadeScreen> createState() => _VelocidadeScreenState();
}
class _VelocidadeScreenState extends State<VelocidadeScreen> {
  static const servidores = {
    'auto': 'Automático (menor ping)',
    'cloudflare': 'Cloudflare (mais próximo)',
    'hetzner': 'Hetzner — Alemanha',
    'thinkbroadband': 'ThinkBroadband — Reino Unido',
    'custom': 'Personalizado (URL)',
  };
  static const urls = {
    'cloudflare': 'https://speed.cloudflare.com/__down?bytes=25000000',
    'hetzner': 'https://speed.hetzner.de/100MB.bin',
    'thinkbroadband': 'http://ipv4.download.thinkbroadband.com/50MB.zip',
  };
  String _sel = 'auto';
  final _url = TextEditingController();
  double _down = 0, _up = 0;
  int _ping = 0;
  String _status = 'Escolha o servidor e teste.', _servNome = '';
  bool _rodando = false;

  Future<int> _latHost(String url) async {
    try {
      final u = Uri.parse(url);
      final t = DateTime.now();
      final s = await Socket.connect(u.host, u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80), timeout: const Duration(seconds: 4));
      s.destroy();
      return DateTime.now().difference(t).inMilliseconds;
    } catch (_) { return 1 << 30; }
  }

  Future<double> _download(String url) async {
    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      final inicio = DateTime.now();
      int total = 0;
      await for (final chunk in resp.stream) {
        total += chunk.length;
        if (total >= 25000000 || DateTime.now().difference(inicio).inSeconds >= 15) break;
      }
      final seg = DateTime.now().difference(inicio).inMilliseconds / 1000.0;
      return seg > 0 ? (total * 8) / seg / 1e6 : 0;
    } finally { client.close(); }
  }

  Future<void> _testar() async {
    setState(() { _rodando = true; _down = 0; _up = 0; _ping = 0; _status = 'Preparando...'; });
    String chave = _sel;
    String? url;
    bool cloud = false;
    if (chave == 'custom') { url = _url.text.trim(); if (url.isEmpty) { setState(() { _rodando = false; _status = 'Cole a URL de um arquivo.'; }); return; } _servNome = 'Personalizado'; }
    else {
      if (chave == 'auto') {
        setState(() => _status = 'Escolhendo servidor mais próximo...');
        int melhor = 1 << 30; String mk = 'cloudflare';
        for (final e in urls.entries) { final ms = await _latHost(e.value); if (ms < melhor) { melhor = ms; mk = e.key; } }
        chave = mk;
      }
      url = urls[chave]; cloud = chave == 'cloudflare'; _servNome = servidores[chave] ?? chave;
    }
    // latência
    setState(() => _status = 'Medindo latência...');
    final lat = await _latHost(url!);
    if (lat < (1 << 30)) setState(() => _ping = lat);
    // download
    setState(() => _status = 'Medindo download...');
    try { final d = await _download(url); setState(() => _down = d); } catch (_) {}
    // upload (só Cloudflare)
    if (cloud) {
      setState(() => _status = 'Medindo upload...');
      try {
        final payload = Uint8List(10000000);
        final t = DateTime.now();
        await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload);
        final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
        setState(() => _up = (payload.length * 8) / seg / 1e6);
      } catch (_) {}
    }
    setState(() { _rodando = false; _status = (cloud ? 'Concluído.' : 'Concluído (upload só no Cloudflare).') + ' Servidor: $_servNome'; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '⚡ Velocidade', desc: 'Download, upload e latência. Escolha o servidor.', filho: Column(children: [
        DropdownButtonFormField<String>(
          value: _sel,
          dropdownColor: kCard,
          decoration: campoDeco(''),
          items: servidores.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: kTxt, fontSize: 14)))).toList(),
          onChanged: (v) => setState(() => _sel = v ?? 'auto'),
        ),
        if (_sel == 'custom') Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: _url, style: const TextStyle(color: kTxt), decoration: campoDeco('https://.../arquivo-de-teste'))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Gauge(valor: _down, label: 'Mbps ↓', cor: kAccent),
          _Gauge(valor: _up, label: 'Mbps ↑', cor: kOk),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(999)), child: Text('Latência: $_ping ms', style: const TextStyle(color: kAccent, fontWeight: FontWeight.w600))),
        const SizedBox(height: 14),
        Text(_status, style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        BotaoRun(_rodando ? 'Testando...' : 'Iniciar teste', onTap: _rodando ? null : _testar),
      ])),
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
    return SizedBox(width: 120, height: 120, child: CustomPaint(
      painter: _GaugePainter(frac, cor),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(valor <= 0 ? '—' : valor.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTxt)),
        Text(label, style: const TextStyle(fontSize: 10, color: kMuted)),
      ])),
    ));
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
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 11..color = const Color(0xFF263253));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * frac, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round..color = cor);
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
      Secao(titulo: '🔐 Força de senha', desc: 'Avaliação local — nada é enviado à rede.', filho: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(obscureText: true, onChanged: _analisar, style: const TextStyle(color: kTxt), decoration: campoDeco('Digite a senha')),
        const SizedBox(height: 14),
        Row(children: List.generate(5, (i) => Expanded(child: Container(height: 9, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: i < _n ? _cor : kCard2, borderRadius: BorderRadius.circular(6)))))),
        const SizedBox(height: 10),
        if (_nivel.isNotEmpty) Text(_nivel, style: TextStyle(color: _cor, fontWeight: FontWeight.bold)),
        Text(_info, style: const TextStyle(color: kMuted)),
      ])),
    ]);
  }
}
