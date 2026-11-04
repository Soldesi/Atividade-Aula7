import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaCompromissos(),
    ),
  );
}

/// Dados de um compromisso já prontos para exibição.
class Compromisso {
  final String titulo;
  final String calendario;
  final DateTime inicio;
  final DateTime? fim;
  final bool diaInteiro;
  final String local;
  final String descricao;

  const Compromisso({
    required this.titulo,
    required this.calendario,
    required this.inicio,
    required this.fim,
    required this.diaInteiro,
    required this.local,
    required this.descricao,
  });
}

class TelaCompromissos extends StatefulWidget {
  const TelaCompromissos({super.key});

  @override
  State<TelaCompromissos> createState() => _TelaCompromissosState();
}

class _TelaCompromissosState extends State<TelaCompromissos> {
  static const List<String> _diasSemana = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  List<Compromisso> _compromissos = [];
  bool _carregando = false;
  String _mensagem = 'Pressione o botão para consultar os compromissos.';

  // ---------- Formatação ----------

  String _dois(int n) => n.toString().padLeft(2, '0');

  String _formatarData(DateTime d) {
    return '${_diasSemana[d.weekday - 1]}, '
        '${_dois(d.day)}/${_dois(d.month)}/${d.year}';
  }

  String _formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

  DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  String _descreverHorario(Compromisso c) {
    final inicio = c.inicio;
    final fim = c.fim;

    if (c.diaInteiro) {
      if (fim != null) {
        // No calendário, o fim de um evento de dia inteiro é exclusivo.
        final ultimo = fim.subtract(const Duration(days: 1));
        if (_soData(ultimo).isAfter(_soData(inicio))) {
          return '${_formatarData(inicio)} até ${_formatarData(ultimo)}';
        }
      }
      return _formatarData(inicio);
    }

    if (fim == null) {
      return '${_formatarData(inicio)}, ${_formatarHora(inicio)}';
    }

    if (_soData(inicio) == _soData(fim)) {
      return '${_formatarData(inicio)}, '
          '${_formatarHora(inicio)} às ${_formatarHora(fim)}';
    }

    return '${_formatarData(inicio)} ${_formatarHora(inicio)} até '
        '${_formatarData(fim)} ${_formatarHora(fim)}';
  }

  // ---------- Consulta ----------

  Future<void> _consultar() async {
    if (_carregando) return;

    setState(() {
      _carregando = true;
      _compromissos = [];
      _mensagem = 'Verificando acesso ao calendário...';
    });

    try {
      var permissao = await _plugin.hasPermissions();

      if (!mounted) return;

      if (permissao.isSuccess && permissao.data != true) {
        permissao = await _plugin.requestPermissions();
      }

      if (!mounted) return;

      if (!permissao.isSuccess) {
        setState(() {
          _mensagem = 'Não foi possível verificar a permissão do calendário.';
        });
        return;
      }

      if (permissao.data != true) {
        setState(() {
          _mensagem =
              'O acesso ao calendário foi negado. Autorize o acesso nas '
              'configurações do aplicativo e tente novamente.';
        });
        return;
      }

      setState(() {
        _mensagem = 'Consultando compromissos...';
      });

      final resultadoCalendarios = await _plugin.retrieveCalendars();

      if (!mounted) return;

      final calendarios = resultadoCalendarios.data;

      if (!resultadoCalendarios.isSuccess || calendarios == null) {
        setState(() {
          _mensagem = 'Não foi possível consultar os calendários.';
        });
        return;
      }

      if (calendarios.isEmpty) {
        setState(() {
          _mensagem = 'Nenhum calendário disponível no dispositivo.';
        });
        return;
      }

      // Hoje (00:00) até o fim do sexto dia seguinte = 7 dias.
      final agora = DateTime.now();
      final inicioPeriodo = DateTime(agora.year, agora.month, agora.day);
      final fimPeriodo = DateTime(agora.year, agora.month, agora.day + 7);
      final parametros = RetrieveEventsParams(
        startDate: inicioPeriodo,
        endDate: fimPeriodo,
      );

      final lista = <Compromisso>[];
      var falhas = 0;

      for (final calendario in calendarios) {
        final id = calendario.id;
        if (id == null) continue;

        final resultado = await _plugin.retrieveEvents(id, parametros);

        if (!mounted) return;

        final eventos = resultado.data;

        if (!resultado.isSuccess || eventos == null) {
          falhas++;
          continue;
        }

        for (final evento in eventos) {
          final inicio = evento.start;
          if (inicio == null) continue;

          lista.add(
            Compromisso(
              titulo: (evento.title ?? '').trim(),
              calendario: calendario.name ?? 'Calendário sem nome',
              inicio: inicio,
              fim: evento.end,
              diaInteiro: evento.allDay ?? false,
              local: (evento.location ?? '').trim(),
              descricao: (evento.description ?? '').trim(),
            ),
          );
        }
      }

      lista.sort((a, b) {
        final porHorario = a.inicio.compareTo(b.inicio);
        if (porHorario != 0) return porHorario;
        return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      });

      setState(() {
        _compromissos = lista;

        if (lista.isEmpty && falhas > 0) {
          _mensagem = 'Não foi possível consultar os compromissos.';
        } else if (lista.isEmpty) {
          _mensagem = 'Nenhum compromisso nos próximos 7 dias.';
        } else if (falhas > 0) {
          _mensagem =
              '${lista.length} compromisso(s) encontrado(s). '
              '$falhas calendário(s) não puderam ser lidos.';
        } else {
          _mensagem = '${lista.length} compromisso(s) encontrado(s).';
        }
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _compromissos = [];
        _mensagem = 'Ocorreu uma falha na consulta dos compromissos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // ---------- Interface ----------

  Widget _linha(IconData icone, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  Widget _cartao(Compromisso c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.titulo.isEmpty ? 'Sem título' : c.titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (c.diaInteiro) ...[
              const SizedBox(height: 6),
              const Chip(
                label: Text('Dia inteiro'),
                visualDensity: VisualDensity.compact,
              ),
            ],
            _linha(Icons.calendar_month, c.calendario),
            _linha(Icons.schedule, _descreverHorario(c)),
            _linha(
              Icons.place,
              c.local.isEmpty ? 'Local não informado' : c.local,
            ),
            _linha(
              Icons.notes,
              c.descricao.isEmpty ? 'Sem descrição' : c.descricao,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compromissos dos próximos 7 dias')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _carregando ? null : _consultar,
              child: const Text('Consultar compromissos'),
            ),
            const SizedBox(height: 12),
            Text(_mensagem),
            const SizedBox(height: 12),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _compromissos.length,
                      itemBuilder: (context, index) =>
                          _cartao(_compromissos[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
