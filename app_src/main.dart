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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class MenuItem {
  final IconData icon;
  final Color cor;
  final String label;
  final Widget tela;
  const MenuItem(this.icon, this.cor, this.label, this.tela);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const itens = [
    MenuItem(Icons.search, kAccent, 'Teste Geral', TesteGeralScreen()),
    MenuItem(Icons.info_outline, Color(0xFF60A5FA), 'Status', StatusScreen()),
    MenuItem(Icons.wifi, Color(0xFF22C55E), 'Canais', CanaisScreen()),
    MenuItem(Icons.network_ping, Color(0xFFF59E0B), 'Conexão', ConexaoScreen()),
    MenuItem(Icons.dns, Color(0xFF8B5CF6), 'DNS', DnsScreen()),
    MenuItem(Icons.map, Color(0xFFEF4444), 'Mapa de Sinal', MapaScreen()),
    MenuItem(Icons.speed, kAccent2, 'Velocidade', VelocidadeScreen()),
    MenuItem(Icons.devices, Color(0xFF06B6D4), 'Dispositivos', DispositivosScreen()),
    MenuItem(Icons.show_chart, Color(0xFF22C55E), 'Estabilidade', EstabilidadeScreen()),
    MenuItem(Icons.sports_esports, Color(0xFFEC4899), 'Qualidade', QualidadeScreen()),
    MenuItem(Icons.qr_code_2, Color(0xFF60A5FA), 'QR Wi-Fi', QrWifiScreen()),
    MenuItem(Icons.router, Color(0xFFF59E0B), 'Roteador', RoteadorScreen()),
    MenuItem(Icons.map_outlined, Color(0xFFEF4444), 'Planta', PlantaScreen()),
    MenuItem(Icons.history, Color(0xFF06B6D4), 'Histórico', HistoricoScreen()),
    MenuItem(Icons.lock_outline, Color(0xFF8B5CF6), 'Senha', SenhaScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(children: const [
              Text('🛜', style: TextStyle(fontSize: 26)),
              SizedBox(width: 8),
              Text('Diagnóstico de Rede', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kTxt)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text('Toque em um teste para começar', style: TextStyle(color: kMuted, fontSize: 13)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(14),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: itens.map((m) => _MenuCard(m)).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem m;
  const _MenuCard(this.m);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Pagina(titulo: m.label, child: m.tela))),
      child: Container(
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: m.cor.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
            child: Icon(m.icon, color: m.cor, size: 26),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(m.label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: kTxt, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _Pagina extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Pagina({required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), backgroundColor: kCard, foregroundColor: kTxt),
      body: child,
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
  final _cliente = TextEditingController();
  final _protocolo = TextEditingController();
  File? _logo;

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null && mounted) setState(() => _logo = File(x.path));
  }

  Future<void> _salvarHistorico() async {
    if (_relatorio.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('hist') ?? [];
    raw.add(jsonEncode({'data': DateTime.now().toString().substring(0, 19), 'cliente': _cliente.text.trim(), 'texto': _relatorio}));
    await prefs.setStringList('hist', raw);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo no histórico.')));
  }

  Future<String> _status0() async {
    final info = NetworkInfo();
    try {
      return 'SSID: ${(await info.getWifiName())?.replaceAll('"', '') ?? '—'}\n'
          'IP: ${await info.getWifiIP() ?? '—'}\n'
          'Máscara: ${await info.getWifiSubmask() ?? '—'}\n'
          'Gateway: ${await info.getWifiGatewayIP() ?? '—'}\n'
          'MAC (BSSID): ${await info.getWifiBSSID() ?? '—'}';
    } catch (e) { return 'erro: $e'; }
  }

  Future<(String, int?, double?)> _ping() async {
    try {
      final r = await Process.run('ping', ['-c', '4', '8.8.8.8']).timeout(const Duration(seconds: 30));
      final out = r.stdout.toString().trim();
      final tempos = RegExp(r'time=([\d.]+)').allMatches(out).map((m) => double.parse(m.group(1)!)).toList();
      final perda = int.tryParse(RegExp(r'(\d+)% packet loss').firstMatch(out)?.group(1) ?? '');
      final media = tempos.isEmpty ? null : tempos.reduce((a, b) => a + b) / tempos.length;
      return (out, perda, media);
    } catch (e) { return ('erro ao executar ping: $e', null, null); }
  }

  Future<String> _tracert() async {
    for (final bin in ['traceroute', '/system/bin/traceroute']) {
      try {
        final r = await Process.run(bin, ['-n', '-m', '15', '8.8.8.8']).timeout(const Duration(seconds: 40));
        final out = (r.stdout.toString() + r.stderr.toString()).trim();
        if (out.isNotEmpty && !out.toLowerCase().contains('not found')) return out;
      } catch (_) {}
    }
    return 'traceroute indisponível neste Android (geralmente exige root).';
  }

  Future<(String, String, String)> _canais() async {
    try {
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) { await WiFiScan.instance.startScan(); await Future.delayed(const Duration(seconds: 3)); }
      final redes = await WiFiScan.instance.getScannedResults();
      if (redes.isEmpty) return ('nenhuma rede detectada', '—', '—');
      final sb = StringBuffer('Redes encontradas: ${redes.length}');
      String best24 = '—', best5 = '—';
      for (final banda in ['2.4', '5']) {
        final lista = redes.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == banda).toList();
        if (lista.isEmpty) { sb.write('\n=== $banda GHz: nenhuma ==='); continue; }
        sb.write('\n=== $banda GHz (${lista.length} redes) ===');
        final porCanal = <int, int>{};
        for (final r in lista) { final c = canalDaFrequencia(r.frequency)!; porCanal[c] = (porCanal[c] ?? 0) + 1; }
        final canais = porCanal.keys.toList()..sort();
        for (final c in canais) { sb.write('\n  Canal $c: ${porCanal[c]} rede(s)'); }
        if (banda == '2.4') {
          double p(int c) => lista.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (d == 0 ? 1.0 : (d < 5 ? (5 - d) / 5 : 0.0)) * rssiParaPorcento(r.level) / 100; });
          best24 = '${[1, 6, 11].reduce((a, b) => p(a) <= p(b) ? a : b)}';
          sb.write('\n  >>> Melhor canal: $best24');
        } else {
          final cand = {...lista.map((r) => canalDaFrequencia(r.frequency)!), 36, 40, 44, 48, 149, 153, 157, 161}.toList()..sort();
          double p(int c) => lista.fold(0.0, (a, r) { final ch = canalDaFrequencia(r.frequency)!; final d = (c - ch).abs(); return a + (ch == c ? 1.0 : (d <= 2 ? 0.3 : 0.0)) * rssiParaPorcento(r.level) / 100; });
          best5 = '${cand.reduce((a, b) => p(a) <= p(b) ? a : b)}';
          sb.write('\n  >>> Melhor canal: $best5');
        }
      }
      return (sb.toString(), best24, best5);
    } catch (e) { return ('erro: $e', '—', '—'); }
  }

  Future<String> _dns() async {
    final linhas = <String>[];
    try {
      final t = DateTime.now();
      final a = await InternetAddress.lookup('google.com');
      final ip = a.firstWhere((x) => x.type == InternetAddressType.IPv4, orElse: () => a.first).address;
      linhas.add('Operadora (sistema): ${DateTime.now().difference(t).inMilliseconds} ms  ->  $ip');
    } catch (_) { linhas.add('Operadora (sistema): falhou'); }
    for (final p in [['Google 8.8.8.8', 'https://dns.google/resolve?name=google.com&type=A', <String, String>{}], ['Cloudflare 1.1.1.1', 'https://cloudflare-dns.com/dns-query?name=google.com&type=A', {'Accept': 'application/dns-json'}]]) {
      try {
        final t = DateTime.now();
        final r = await http.get(Uri.parse(p[1] as String), headers: p[2] as Map<String, String>).timeout(const Duration(seconds: 8));
        final d = jsonDecode(r.body);
        final ans = (d['Answer'] as List?)?.where((a) => a['type'] == 1).map((a) => a['data']).toList() ?? [];
        linhas.add('${p[0]}: ${DateTime.now().difference(t).inMilliseconds} ms  ->  ${ans.isNotEmpty ? ans.first : "sem registro A"}');
      } catch (_) { linhas.add('${p[0]}: erro'); }
    }
    return linhas.join('\n');
  }

  Future<(double, double, int)> _vel() async {
    int ping = 0;
    double down = 0, up = 0;
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
    try {
      final payload = Uint8List(8000000);
      final t = DateTime.now();
      await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload).timeout(const Duration(seconds: 30));
      final seg = DateTime.now().difference(t).inMilliseconds / 1000.0;
      if (seg > 0) up = (payload.length * 8) / seg / 1e6;
    } catch (_) {}
    return (down, up, ping);
  }

  Future<void> _rodar() async {
    setState(() { _rodando = true; _relatorio = ''; });
    final sb = StringBuffer();
    final bar = '=' * 46;
    sb.writeln(bar);
    sb.writeln(' RELATÓRIO DE REDE');
    sb.writeln(' Data: ${DateTime.now().toString().substring(0, 19)}');
    if (_cliente.text.trim().isNotEmpty) sb.writeln(' Cliente: ${_cliente.text.trim()}');
    if (_protocolo.text.trim().isNotEmpty) sb.writeln(' Protocolo: ${_protocolo.text.trim()}');
    sb.writeln(bar);

    setState(() => _status = 'Coletando status...');
    sb.writeln('\n[1] STATUS DA REDE\n${await _status0()}');

    setState(() => _status = 'Testando conexão (ping + traceroute)...');
    final (pingTxt, perda, media) = await _ping();
    sb.writeln('\n[2] CONEXÃO (PING)\n$pingTxt');
    sb.writeln('\n[2b] TRACEROUTE\n${await _tracert()}');

    setState(() => _status = 'Escaneando canais...');
    final (canTxt, b24, b5) = await _canais();
    sb.writeln('\n[3] CANAIS WI-FI\n$canTxt');

    setState(() => _status = 'Testando DNS...');
    sb.writeln('\n[4] DNS\n${await _dns()}');

    setState(() => _status = 'Medindo velocidade...');
    final (down, up, vping) = await _vel();
    sb.writeln('\n[5] VELOCIDADE (Cloudflare)\nDownload: ${down.toStringAsFixed(1)} Mbps | Upload: ${up.toStringAsFixed(1)} Mbps | Latência: $vping ms');

    // Resumo
    sb.writeln('\n$bar\n RESUMO');
    sb.writeln(perda == 100 ? ' ✗ Sem resposta da internet (perda 100%).' : ' ✓ Internet respondendo${media != null ? " (latência média ${media.toStringAsFixed(0)} ms)" : ""}.');
    sb.writeln(' • Velocidade: ~${down.toStringAsFixed(1)} Mbps down / ~${up.toStringAsFixed(1)} Mbps up.');
    sb.writeln(' • Melhor canal 2.4 GHz: $b24 | 5 GHz: $b5.');
    sb.writeln(bar);

    if (mounted) setState(() { _rodando = false; _status = 'Concluído.'; _relatorio = sb.toString(); });
  }

  Future<void> _compartilharTxt() async {
    if (_relatorio.isEmpty) return;
    await Share.share(_relatorio, subject: 'Relatório de Rede');
  }

  Future<void> _whatsapp() async {
    if (_relatorio.isEmpty) return;
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_relatorio)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _gerarPdf() async {
    if (_relatorio.isEmpty) return;
    pw.MemoryImage? logoImg;
    if (_logo != null) { try { logoImg = pw.MemoryImage(await _logo!.readAsBytes()); } catch (_) {} }
    await Printing.layoutPdf(onLayout: (format) async {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(build: (c) => [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              if (logoImg != null) pw.Padding(padding: const pw.EdgeInsets.only(right: 12), child: pw.Image(logoImg, width: 60, height: 60)),
              pw.Text('Relatório de Rede', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 10),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _relatorio.split('\n').map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 9))).toList()),
          ]));
      return doc.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🔎 Teste Geral', desc: 'Roda todos os testes e gera um relatório completo pra compartilhar (TXT/WhatsApp) ou salvar em PDF.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _cliente, style: const TextStyle(color: kTxt), decoration: campoDeco('Cliente (opcional)')),
        const SizedBox(height: 8),
        TextField(controller: _protocolo, style: const TextStyle(color: kTxt), decoration: campoDeco('Protocolo / chamado (opcional)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _pickLogo, icon: Icon(_logo == null ? Icons.add_photo_alternate_outlined : Icons.check, size: 18), label: Text(_logo == null ? 'Logo no PDF (opcional)' : 'Logo selecionada ✓'), style: OutlinedButton.styleFrom(foregroundColor: kMuted, side: const BorderSide(color: kLine))),
        const SizedBox(height: 12),
        BotaoRun(_rodando ? 'Rodando...' : 'Rodar teste geral', onTap: _rodando ? null : _rodar),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          if (_rodando) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Expanded(child: Text(_status, style: const TextStyle(color: kMuted))),
        ])),
        if (_relatorio.isNotEmpty) ...[
          saidaMono(_relatorio),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BotaoRun('WhatsApp', cor: const Color(0xFF25D366), onTap: _whatsapp)),
            const SizedBox(width: 8),
            Expanded(child: BotaoRun('TXT', cor: kOk, onTap: _compartilharTxt)),
            const SizedBox(width: 8),
            Expanded(child: BotaoRun('PDF', cor: kBad, onTap: _gerarPdf)),
          ]),
          const SizedBox(height: 8),
          BotaoRun('Salvar no histórico', cor: kCard2, onTap: _salvarHistorico),
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
      // Segurança (WPA2/WPA3/aberta) via scan
      try {
        final can = await WiFiScan.instance.canStartScan();
        if (can == CanStartScan.yes) { await WiFiScan.instance.startScan(); await Future.delayed(const Duration(seconds: 2)); }
        final res = await WiFiScan.instance.getScannedResults();
        final bssid = _d['MAC (BSSID)']?.toLowerCase();
        final me = res.where((r) => r.bssid.toLowerCase() == bssid);
        _d['Segurança'] = me.isNotEmpty ? segDaCapabilities(me.first.capabilities) : '—';
      } catch (_) { _d['Segurança'] = '—'; }
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

// ========================= MAPA POR CÔMODOS (dBm, 2.4 e 5 GHz) =========================
class _Comodo {
  String nome;
  int? r24; // dBm
  int? r5;  // dBm
  _Comodo(this.nome);
}

String qualDbm(int? d) {
  if (d == null) return '';
  if (d >= -55) return 'ótimo';
  if (d >= -65) return 'bom';
  if (d >= -72) return 'ok';
  if (d >= -80) return 'fraco';
  return 'ruim';
}

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final List<_Comodo> _comodos = [];
  String? _ssid;
  bool _medindo = false;

  Future<(int?, int?)> _medir() async {
    try {
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) { await WiFiScan.instance.startScan(); await Future.delayed(const Duration(milliseconds: 600)); }
      final res = await WiFiScan.instance.getScannedResults();
      _ssid ??= (await NetworkInfo().getWifiName())?.replaceAll('"', '');
      Iterable<WiFiAccessPoint> meu = res;
      if (_ssid != null && _ssid!.isNotEmpty) { final f = res.where((r) => r.ssid == _ssid); if (f.isNotEmpty) meu = f; }
      int? best(String b) {
        final g = meu.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == b);
        return g.isEmpty ? null : g.map((r) => r.level).reduce(max); // dBm (max = mais forte)
      }
      return (best('2.4'), best('5'));
    } catch (_) { return (null, null); }
  }

  Future<void> _medirComodo(_Comodo c) async {
    await Permission.locationWhenInUse.request();
    setState(() => _medindo = true);
    final (a, b) = await _medir();
    if (mounted) setState(() { c.r24 = a; c.r5 = b; _medindo = false; });
  }

  void _novo() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('Novo cômodo', style: TextStyle(color: kTxt)),
      content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: kTxt), decoration: campoDeco('ex: Sala, Quarto, Cozinha')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () { final n = ctrl.text.trim(); Navigator.pop(ctx); setState(() => _comodos.add(_Comodo(n.isEmpty ? 'Cômodo ${_comodos.length + 1}' : n))); }, child: const Text('Adicionar')),
      ],
    ));
  }

  Widget _barraBanda(String banda, int? dbm) {
    final pct = dbm == null ? 0 : rssiParaPorcento(dbm);
    final cor = dbm == null ? kCard2 : corSinal(pct);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        SizedBox(width: 54, child: Text('$banda GHz', style: const TextStyle(color: kMuted, fontSize: 12))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct / 100, minHeight: 12, backgroundColor: kCard2, color: cor))),
        const SizedBox(width: 8),
        SizedBox(width: 118, child: Text(dbm == null ? '—' : '$dbm dBm ($pct%) ${qualDbm(dbm)}', textAlign: TextAlign.right, style: TextStyle(color: dbm == null ? kMuted : cor, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _diag() {
    final m24 = _comodos.where((c) => c.r24 != null).toList();
    final m5 = _comodos.where((c) => c.r5 != null).toList();
    if (m24.isEmpty && m5.isEmpty) return 'Cadastre os cômodos e meça o sinal em cada um para o diagnóstico.';
    final sb = StringBuffer();
    void banda(String nome, List<_Comodo> lista, int? Function(_Comodo) f) {
      if (lista.isEmpty) return;
      final melhor = lista.reduce((a, b) => f(a)! >= f(b)! ? a : b);
      final piores = lista.where((c) => rssiParaPorcento(f(c)!) < 40).toList();
      sb.writeln('$nome — melhor ponto: ${melhor.nome} (${f(melhor)} dBm).');
      if (piores.isNotEmpty) {
        sb.writeln('  ⚠ Repetidor recomendado: ${piores.map((c) => c.nome).join(", ")} com sinal fraco. Instale um repetidor/mesh entre o roteador e ${piores.first.nome}.');
      } else {
        sb.writeln('  ✓ Cobertura boa — sem necessidade aparente de repetidor.');
      }
    }
    banda('2.4 GHz', m24, (c) => c.r24);
    banda('5 GHz', m5, (c) => c.r5);
    if (m5.isNotEmpty) sb.writeln('Obs.: o 5 GHz alcança menos que o 2.4; é normal cair mais rápido longe do roteador.');
    return sb.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(
        titulo: '📍 Mapa de Sinal por Cômodo',
        desc: 'Cadastre os cômodos da casa e meça o sinal em cada um. Mostra a potência em dBm (e %) no 2.4 e 5 GHz, e aponta onde pega melhor e se precisa de repetidor.',
        filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_medindo ? 'medindo...' : '${_comodos.length} cômodo(s)', style: const TextStyle(color: kMuted, fontSize: 13)),
            TextButton.icon(onPressed: _novo, icon: const Icon(Icons.add, size: 18), label: const Text('Cômodo')),
          ]),
          if (_comodos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum cômodo. Toque em "Cômodo", vá até o local e meça.', style: TextStyle(color: kMuted, fontSize: 13))),
          ..._comodos.map((c) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700, color: kTxt))),
                    TextButton(onPressed: () => _medirComodo(c), child: const Text('Medir aqui')),
                    IconButton(onPressed: () => setState(() => _comodos.remove(c)), icon: const Icon(Icons.close, color: kMuted, size: 18)),
                  ]),
                  _barraBanda('2.4', c.r24),
                  _barraBanda('5', c.r5),
                ]),
              )),
          if (_comodos.any((c) => c.r24 != null || c.r5 != null)) Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
            child: Text(_diag(), style: const TextStyle(color: kTxt, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          const Text('Como usar: adicione um cômodo, vá fisicamente até ele e toque em "Medir aqui". Repita em cada parte da casa.', style: TextStyle(color: kMuted, fontSize: 11)),
        ]),
      ),
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

// ========================= DISPOSITIVOS NA REDE =========================
String segDaCapabilities(String c) {
  final u = c.toUpperCase();
  if (u.contains('WPA3') || u.contains('SAE')) return 'WPA3';
  if (u.contains('RSN') || u.contains('WPA2')) return 'WPA2';
  if (u.contains('WPA')) return 'WPA';
  if (u.contains('WEP')) return 'WEP';
  return 'Aberta';
}

class DispositivosScreen extends StatefulWidget {
  const DispositivosScreen({super.key});
  @override
  State<DispositivosScreen> createState() => _DispositivosScreenState();
}
class _DispositivosScreenState extends State<DispositivosScreen> {
  bool _scan = false;
  String _status = 'Toque para escanear a rede e ver quem está conectado.';
  List<Map<String, String>> _devs = [];

  int _ipNum(String ip) { final p = ip.split('.'); return p.length == 4 ? (int.tryParse(p[3]) ?? 0) : 0; }

  Future<void> _escanear() async {
    setState(() { _scan = true; _devs = []; _status = 'Preparando...'; });
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    final gw = await info.getWifiGatewayIP();
    if (ip == null || !ip.contains('.')) { setState(() { _scan = false; _status = 'Sem IP — conecte ao Wi-Fi.'; }); return; }
    final base = ip.split('.').take(3).join('.');
    final alvos = [for (int i = 1; i <= 254; i++) '$base.$i'];
    final vivos = <String>{};
    const chunk = 25;
    for (int i = 0; i < alvos.length; i += chunk) {
      final part = alvos.skip(i).take(chunk).toList();
      final res = await Future.wait(part.map((x) async {
        try { final r = await Process.run('ping', ['-c', '1', '-W', '1', x]).timeout(const Duration(seconds: 3)); return r.exitCode == 0 ? x : null; } catch (_) { return null; }
      }));
      vivos.addAll(res.whereType<String>());
      if (mounted) setState(() => _status = 'Escaneando... ${(i + chunk).clamp(0, 254)}/254');
    }
    final macs = <String, String>{};
    try {
      final arp = await File('/proc/net/arp').readAsString();
      for (final l in arp.split('\n').skip(1)) {
        final p = l.trim().split(RegExp(r'\s+'));
        if (p.length >= 4 && p[2] == '0x2' && p[3] != '00:00:00:00:00:00') { macs[p[0]] = p[3]; vivos.add(p[0]); }
      }
    } catch (_) {}
    final lista = <Map<String, String>>[{'ip': ip, 'mac': '(este aparelho)', 'tag': 'você'}];
    final ordenados = vivos.toList()..sort((a, b) => _ipNum(a).compareTo(_ipNum(b)));
    for (final v in ordenados) {
      if (v == ip) continue;
      lista.add({'ip': v, 'mac': macs[v] ?? '—', 'tag': v == gw ? 'roteador' : ''});
    }
    if (mounted) setState(() { _scan = false; _devs = lista; _status = '${lista.length} dispositivo(s) na rede.'; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '📡 Dispositivos na Rede', desc: 'Varre a rede local e lista os aparelhos conectados (IP e MAC). Útil pra achar intrusos ou explicar lentidão por excesso de aparelhos.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BotaoRun(_scan ? 'Escaneando...' : 'Escanear rede', onTap: _scan ? null : _escanear),
        const SizedBox(height: 10),
        Text(_status, style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 6),
        ..._devs.map((d) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(d['tag'] == 'roteador' ? Icons.router : (d['tag'] == 'você' ? Icons.smartphone : Icons.devices), color: kAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ip']!, style: const TextStyle(fontWeight: FontWeight.w700, color: kTxt)),
                  Text(d['mac']!, style: const TextStyle(color: kMuted, fontSize: 12)),
                ])),
                if ((d['tag'] ?? '').isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: kAccent.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)), child: Text(d['tag']!, style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            )),
        if (!_scan && _devs.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Obs.: em alguns Android o MAC pode não aparecer (restrição do sistema) — o IP e a contagem continuam valendo.', style: TextStyle(color: kMuted, fontSize: 11))),
      ])),
    ]);
  }
}

// ========================= ESTABILIDADE (ping contínuo + gráfico) =========================
class EstabilidadeScreen extends StatefulWidget {
  const EstabilidadeScreen({super.key});
  @override
  State<EstabilidadeScreen> createState() => _EstabilidadeScreenState();
}
class _EstabilidadeScreenState extends State<EstabilidadeScreen> {
  final _host = TextEditingController(text: '8.8.8.8');
  final List<double?> _amostras = [];
  bool _rodando = false;
  Timer? _timer;
  int _env = 0, _perd = 0;

  void _iniciar() {
    setState(() { _rodando = true; _amostras.clear(); _env = 0; _perd = 0; });
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _umPing());
  }
  void _parar() { _timer?.cancel(); setState(() => _rodando = false); }
  Future<void> _umPing() async {
    _env++;
    double? ms;
    try {
      final r = await Process.run('ping', ['-c', '1', '-W', '2', _host.text.trim()]).timeout(const Duration(seconds: 4));
      final m = RegExp(r'time=([\d.]+)').firstMatch(r.stdout.toString());
      if (m != null) ms = double.parse(m.group(1)!);
    } catch (_) {}
    if (ms == null) _perd++;
    if (mounted) setState(() { _amostras.add(ms); if (_amostras.length > 60) _amostras.removeAt(0); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final validas = _amostras.whereType<double>().toList();
    final mn = validas.isEmpty ? 0 : validas.reduce(min);
    final mx = validas.isEmpty ? 0 : validas.reduce(max);
    final avg = validas.isEmpty ? 0 : validas.reduce((a, b) => a + b) / validas.length;
    final jit = (mx - mn).toDouble();
    final perdaPct = _env == 0 ? 0 : (_perd * 100 / _env);
    return ListView(children: [
      Secao(titulo: '📈 Estabilidade', desc: 'Ping contínuo com gráfico ao vivo. Deixe rodando para flagrar picos e quedas da conexão.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _host, style: const TextStyle(color: kTxt), decoration: campoDeco('destino (ex: 8.8.8.8)')),
        const SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(color: const Color(0xFF080D1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(painter: _LatChart(_amostras), child: const SizedBox.expand()),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('${avg.toStringAsFixed(0)}', 'média ms'),
          _stat('${mx.toStringAsFixed(0)}', 'máx ms'),
          _stat('${jit.toStringAsFixed(0)}', 'jitter ms'),
          _stat('${perdaPct.toStringAsFixed(0)}%', 'perda'),
        ]),
        const SizedBox(height: 12),
        BotaoRun(_rodando ? 'Parar' : 'Iniciar', cor: _rodando ? kBad : kOk, onTap: _rodando ? _parar : _iniciar),
      ])),
    ]);
  }
  Widget _stat(String v, String l) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kAccent)),
        Text(l, style: const TextStyle(fontSize: 10, color: kMuted)),
      ]);
}
class _LatChart extends CustomPainter {
  final List<double?> dados;
  _LatChart(this.dados);
  @override
  void paint(Canvas canvas, Size size) {
    final validas = dados.whereType<double>().toList();
    if (validas.isEmpty) return;
    final mx = max(validas.reduce(max), 20.0);
    final n = dados.length;
    final dx = n <= 1 ? size.width : size.width / (n - 1);
    final linha = Paint()..color = kAccent..strokeWidth = 2..style = PaintingStyle.stroke;
    Path? path;
    for (int i = 0; i < n; i++) {
      final v = dados[i];
      if (v == null) {
        if (path != null) { canvas.drawPath(path, linha); path = null; }
        final x = i * dx;
        canvas.drawCircle(Offset(x, size.height - 6), 3, Paint()..color = kBad);
        continue;
      }
      final x = i * dx;
      final y = size.height - (v / mx) * (size.height - 12) - 6;
      if (path == null) { path = Path()..moveTo(x, y); } else { path.lineTo(x, y); }
    }
    if (path != null) canvas.drawPath(path, linha);
  }
  @override
  bool shouldRepaint(covariant _LatChart old) => true;
}

// ========================= QUALIDADE (jogos + streaming) =========================
class QualidadeScreen extends StatefulWidget {
  const QualidadeScreen({super.key});
  @override
  State<QualidadeScreen> createState() => _QualidadeScreenState();
}
class _QualidadeScreenState extends State<QualidadeScreen> {
  bool _rodando = false;
  String _jogos = '', _streaming = '', _status = 'Toque para testar.';

  Future<int> _lat(String host, int port) async {
    try { final t = DateTime.now(); final s = await Socket.connect(host, port, timeout: const Duration(seconds: 4)); s.destroy(); return DateTime.now().difference(t).inMilliseconds; } catch (_) { return -1; }
  }

  Future<void> _testar() async {
    setState(() { _rodando = true; _jogos = ''; _streaming = ''; _status = 'Testando latência (jogos)...'; });
    // jogos: latência a vários servidores, 3 medições cada
    final hosts = {'Cloudflare': 'speed.cloudflare.com', 'Google': 'google.com', 'AWS': 'aws.amazon.com'};
    final medias = <int>[];
    for (final h in hosts.values) {
      final ms = <int>[];
      for (int i = 0; i < 3; i++) { final v = await _lat(h, 443); if (v >= 0) ms.add(v); }
      if (ms.isNotEmpty) medias.add(ms.reduce((a, b) => a + b) ~/ ms.length);
    }
    if (medias.isNotEmpty) {
      final avg = medias.reduce((a, b) => a + b) ~/ medias.length;
      final jit = medias.reduce(max) - medias.reduce(min);
      final nota = avg < 40 ? 'A (excelente)' : avg < 80 ? 'B (bom)' : avg < 150 ? 'C (jogável)' : 'D (ruim)';
      _jogos = 'Latência média: $avg ms | jitter: $jit ms\nNota para jogos online: $nota';
    } else { _jogos = 'Não foi possível medir.'; }

    setState(() => _status = 'Testando capacidade (streaming)...');
    double mbps = 0;
    try {
      final client = http.Client();
      final resp = await client.send(http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=15000000')));
      final inicio = DateTime.now();
      int total = 0;
      await for (final c in resp.stream) { total += c.length; if (total >= 12000000 || DateTime.now().difference(inicio).inSeconds >= 10) break; }
      client.close();
      final seg = DateTime.now().difference(inicio).inMilliseconds / 1000.0;
      if (seg > 0) mbps = (total * 8) / seg / 1e6;
    } catch (_) {}
    String ok(double need) => mbps >= need ? '✓' : '✗';
    _streaming = 'Download medido: ${mbps.toStringAsFixed(1)} Mbps\n'
        '${ok(3)} SD (3 Mbps)   ${ok(5)} HD 720p (5 Mbps)\n'
        '${ok(8)} Full HD 1080p (8 Mbps)   ${ok(25)} 4K (25 Mbps)';

    if (mounted) setState(() { _rodando = false; _status = 'Concluído.'; });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🎮 Qualidade (Jogos & Streaming)', desc: 'Mede se a conexão é boa para jogos online e qual qualidade de vídeo ela aguenta.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BotaoRun(_rodando ? 'Testando...' : 'Testar', onTap: _rodando ? null : _testar),
        const SizedBox(height: 10),
        Text(_status, style: const TextStyle(color: kMuted, fontSize: 13)),
        if (_jogos.isNotEmpty) ...[const SizedBox(height: 12), const Text('🎮 Jogos', style: TextStyle(fontWeight: FontWeight.bold, color: kTxt)), Padding(padding: const EdgeInsets.only(top: 4), child: Text(_jogos, style: const TextStyle(color: kMuted)))],
        if (_streaming.isNotEmpty) ...[const SizedBox(height: 12), const Text('📺 Streaming', style: TextStyle(fontWeight: FontWeight.bold, color: kTxt)), Padding(padding: const EdgeInsets.only(top: 4), child: Text(_streaming, style: const TextStyle(color: kMuted)))],
      ])),
    ]);
  }
}


// ========================= QR CODE DO WI-FI =========================
class QrWifiScreen extends StatefulWidget {
  const QrWifiScreen({super.key});
  @override
  State<QrWifiScreen> createState() => _QrWifiScreenState();
}
class _QrWifiScreenState extends State<QrWifiScreen> {
  final _ssid = TextEditingController();
  final _senha = TextEditingController();
  String _seg = 'WPA';
  @override
  void initState() {
    super.initState();
    NetworkInfo().getWifiName().then((v) { if (v != null && mounted) setState(() => _ssid.text = v.replaceAll('"', '')); });
  }
  String get _payload {
    final t = _seg == 'nopass' ? 'nopass' : _seg;
    String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll(':', r'\:');
    return 'WIFI:T:$t;S:${esc(_ssid.text)};P:${esc(_senha.text)};;';
  }
  @override
  Widget build(BuildContext context) {
    final valido = _ssid.text.trim().isNotEmpty;
    return ListView(children: [
      Secao(titulo: '📷 QR Code do Wi-Fi', desc: 'Gere um QR Code para o cliente conectar apontando a câmera. (A senha você digita — o Android não deixa o app ler a senha salva.)', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _ssid, onChanged: (_) => setState(() {}), style: const TextStyle(color: kTxt), decoration: campoDeco('Nome da rede (SSID)')),
        const SizedBox(height: 10),
        TextField(controller: _senha, onChanged: (_) => setState(() {}), style: const TextStyle(color: kTxt), decoration: campoDeco('Senha')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _seg, dropdownColor: kCard, decoration: campoDeco(''),
          items: const [
            DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3', style: TextStyle(color: kTxt))),
            DropdownMenuItem(value: 'WEP', child: Text('WEP', style: TextStyle(color: kTxt))),
            DropdownMenuItem(value: 'nopass', child: Text('Aberta (sem senha)', style: TextStyle(color: kTxt))),
          ],
          onChanged: (v) => setState(() => _seg = v ?? 'WPA'),
        ),
        const SizedBox(height: 18),
        if (valido) Center(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: QrImageView(data: _payload, size: 220, backgroundColor: Colors.white),
        )) else const Center(child: Text('Informe o nome da rede para gerar o QR.', style: TextStyle(color: kMuted))),
      ])),
    ]);
  }
}

// ========================= ATALHO PRO ROTEADOR =========================
class RoteadorScreen extends StatefulWidget {
  const RoteadorScreen({super.key});
  @override
  State<RoteadorScreen> createState() => _RoteadorScreenState();
}
class _RoteadorScreenState extends State<RoteadorScreen> {
  String? _gw;
  @override
  void initState() {
    super.initState();
    NetworkInfo().getWifiGatewayIP().then((v) { if (mounted) setState(() => _gw = v); });
  }
  Future<void> _abrir() async {
    if (_gw == null) return;
    final uri = Uri.parse('http://$_gw');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o navegador.')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🖥️ Painel do Roteador', desc: 'Abre a página de configuração do roteador no navegador.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)), child: Row(children: [
          const Text('Gateway: ', style: TextStyle(color: kMuted)),
          Text(_gw ?? '—', style: const TextStyle(color: kTxt, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(height: 14),
        BotaoRun('Abrir painel do roteador', onTap: _gw == null ? null : _abrir),
        const SizedBox(height: 14),
        const Text('Dicas de acesso comuns:\n• Usuário/senha costumam ser admin/admin ou estão na etiqueta do roteador.\n• Se não abrir, digite o IP do gateway direto no navegador.', style: TextStyle(color: kMuted, fontSize: 12)),
      ])),
    ]);
  }
}


// ========================= PLANTA REAL (mapa de calor sobre a imagem) =========================
class _PP {
  final Offset rel;
  final int? r24;
  final int? r5;
  _PP(this.rel, this.r24, this.r5);
}

class PlantaScreen extends StatefulWidget {
  const PlantaScreen({super.key});
  @override
  State<PlantaScreen> createState() => _PlantaScreenState();
}
class _PlantaScreenState extends State<PlantaScreen> {
  File? _img;
  String _banda = '2.4';
  String? _ssid;
  bool _medindo = false;
  final List<_PP> _pts = [];

  Future<(int?, int?)> _medir() async {
    try {
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) { await WiFiScan.instance.startScan(); await Future.delayed(const Duration(milliseconds: 600)); }
      final res = await WiFiScan.instance.getScannedResults();
      _ssid ??= (await NetworkInfo().getWifiName())?.replaceAll('"', '');
      Iterable<WiFiAccessPoint> meu = res;
      if (_ssid != null && _ssid!.isNotEmpty) { final f = res.where((r) => r.ssid == _ssid); if (f.isNotEmpty) meu = f; }
      int? best(String b) { final g = meu.where((r) => bandaDoCanal(canalDaFrequencia(r.frequency)) == b); return g.isEmpty ? null : g.map((r) => r.level).reduce(max); }
      return (best('2.4'), best('5'));
    } catch (_) { return (null, null); }
  }

  Future<void> _carregar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null && mounted) setState(() => _img = File(x.path));
  }

  Future<void> _tap(Offset rel) async {
    if (_img == null) return;
    await Permission.locationWhenInUse.request();
    setState(() => _medindo = true);
    final (a, b) = await _medir();
    if (mounted) setState(() { _pts.add(_PP(rel, a, b)); _medindo = false; });
  }

  int? _v(_PP p) => _banda == '2.4' ? p.r24 : p.r5;

  String _diag() {
    final vals = _pts.map(_v).whereType<int>().toList();
    if (vals.isEmpty) return 'Carregue a planta e toque nos locais da casa para medir.';
    final melhor = _pts.where((p) => _v(p) != null).reduce((a, b) => _v(a)! >= _v(b)! ? a : b);
    final fracos = _pts.where((p) { final v = _v(p); return v != null && rssiParaPorcento(v) < 40; }).length;
    final sb = StringBuffer('Banda $_banda GHz — pontos: ${vals.length} | melhor: ${_v(melhor)} dBm (${rssiParaPorcento(_v(melhor)!)}%)');
    if (fracos >= 1) sb.write('\n⚠ $fracos ponto(s) fraco(s) — repetidor/mesh recomendado nessas áreas.');
    else sb.write('\n✓ Cobertura boa nesta banda.');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '🗺️ Planta da Casa (mapa de calor)', desc: 'Carregue a planta (ou uma foto dela), ande pela casa e toque no ponto onde está — o sinal medido aparece sobre a planta.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: ['2.4', '5'].map((b) {
          final sel = _banda == b;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(
            onTap: () => setState(() => _banda = b),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 9), alignment: Alignment.center, decoration: BoxDecoration(gradient: sel ? const LinearGradient(colors: [kAccent, kAccent2]) : null, color: sel ? null : kCard2, borderRadius: BorderRadius.circular(10)), child: Text('$b GHz', style: TextStyle(color: sel ? const Color(0xFF041320) : kMuted, fontWeight: FontWeight.w700))),
          )));
        }).toList()),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, cons) {
          final w = cons.maxWidth, h = 360.0;
          return GestureDetector(
            onTapDown: (d) => _tap(Offset(d.localPosition.dx / w, d.localPosition.dy / h)),
            child: Container(
              width: w, height: h,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1020), borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine),
                image: _img != null ? DecorationImage(image: FileImage(_img!), fit: BoxFit.contain) : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                if (_img == null) const Center(child: Text('Toque em "Carregar planta"', style: TextStyle(color: kMuted))),
                ..._pts.map((p) {
                  final v = _v(p);
                  final cor = v == null ? Colors.grey : corSinal(rssiParaPorcento(v));
                  return Positioned(
                    left: p.rel.dx * w - 16, top: p.rel.dy * h - 16,
                    child: Container(
                      width: 32, height: 32, alignment: Alignment.center,
                      decoration: BoxDecoration(color: cor.withValues(alpha: .85), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text(v == null ? '—' : '$v', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
              ]),
            ),
          );
        }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: BotaoRun(_img == null ? 'Carregar planta' : 'Trocar planta', cor: kCard2, onTap: _carregar)),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: _pts.isEmpty ? null : () => setState(() => _pts.clear()), icon: const Icon(Icons.delete_outline)),
        ]),
        Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)), child: Text(_medindo ? 'medindo ponto...' : _diag(), style: const TextStyle(color: kTxt, fontSize: 13))),
      ])),
    ]);
  }
}

// ========================= HISTÓRICO DE ATENDIMENTOS =========================
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});
  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}
class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Map<String, dynamic>> _itens = [];
  @override
  void initState() { super.initState(); _carregar(); }
  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('hist') ?? [];
    setState(() => _itens = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList().reversed.toList());
  }
  Future<void> _apagar(int idxReverso) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('hist') ?? [];
    final realIdx = raw.length - 1 - idxReverso;
    if (realIdx >= 0 && realIdx < raw.length) { raw.removeAt(realIdx); await prefs.setStringList('hist', raw); }
    _carregar();
  }
  void _ver(Map<String, dynamic> it) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: Text(it['cliente']?.toString().isNotEmpty == true ? it['cliente'] : 'Relatório', style: const TextStyle(color: kTxt, fontSize: 16)),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(it['texto'] ?? '', style: const TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 11)))),
      actions: [
        TextButton(onPressed: () { Share.share(it['texto'] ?? ''); }, child: const Text('Compartilhar')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
      ],
    ));
  }
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Secao(titulo: '📁 Histórico de Atendimentos', desc: 'Relatórios salvos no aparelho. Toque para ver ou compartilhar.', filho: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_itens.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Nenhum relatório salvo ainda. No Teste Geral, toque em "Salvar" após rodar.', style: TextStyle(color: kMuted, fontSize: 13))),
        ..._itens.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kCard2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.description, color: kAccent),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(onTap: () => _ver(e.value), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.value['cliente']?.toString().isNotEmpty == true ? e.value['cliente'] : 'Sem cliente', style: const TextStyle(color: kTxt, fontWeight: FontWeight.w600)),
                  Text(e.value['data'] ?? '', style: const TextStyle(color: kMuted, fontSize: 12)),
                ]))),
                IconButton(onPressed: () => _apagar(e.key), icon: const Icon(Icons.close, color: kMuted, size: 18)),
              ]),
            )),
      ])),
    ]);
  }
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
