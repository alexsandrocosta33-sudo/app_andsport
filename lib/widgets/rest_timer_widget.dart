import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Widget de cronômetro de descanso entre séries.
/// Exibe progresso circular, permite configurar o tempo e vibra ao finalizar.
class RestTimerWidget extends StatefulWidget {
  const RestTimerWidget({
    super.key,
    this.tempoPadrao = 60,
    this.onConcluido,
  });

  /// Tempo inicial em segundos. Padrão: 60s.
  final int tempoPadrao;

  /// Callback chamado quando o cronômetro chega a zero.
  final VoidCallback? onConcluido;

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget>
    with SingleTickerProviderStateMixin {
  static const _opcoesTempo = [30, 60, 90, 120, 180];

  late int _tempoTotal;
  late int _tempoRestante;
  Timer? _timer;
  bool _ativo = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _tempoTotal = widget.tempoPadrao;
    _tempoRestante = _tempoTotal;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _iniciar() {
    if (_ativo || _tempoRestante == 0) return;
    setState(() => _ativo = true);
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tempoRestante <= 1) {
        timer.cancel();
        _pulseController.stop();
        setState(() {
          _tempoRestante = 0;
          _ativo = false;
        });
        _vibrarConclusao();
        widget.onConcluido?.call();
      } else {
        setState(() => _tempoRestante--);
      }
    });
  }

  void _pausar() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() => _ativo = false);
  }

  void _reiniciar() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _tempoRestante = _tempoTotal;
      _ativo = false;
    });
  }

  void _pular() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _tempoRestante = 0;
      _ativo = false;
    });
    widget.onConcluido?.call();
  }

  void _adicionarTrinta() {
    setState(() {
      _tempoRestante += 30;
      _tempoTotal = math.max(_tempoTotal, _tempoRestante);
    });
  }

  void _definirTempo(int segundos) {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _tempoTotal = segundos;
      _tempoRestante = segundos;
      _ativo = false;
    });
  }

  Future<void> _vibrarConclusao() async {
    try {
      final temVibracao = await Vibration.hasVibrator() ?? false;
      if (temVibracao) {
        // 3 pulsos para sinalizar o fim do descanso
        await Vibration.vibrate(pattern: [0, 400, 150, 400, 150, 400]);
      }
    } catch (_) {
      // Ignora erros de vibração — não é funcionalidade crítica
    }
  }

  String _formatarTempo(int segundos) {
    final min = segundos ~/ 60;
    final sec = segundos % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Color get _corProgresso {
    if (_tempoRestante <= 10) return AppColors.erro;
    if (_tempoRestante <= 30) return AppColors.aviso;
    return AppColors.acento;
  }

  double get _progresso =>
      _tempoTotal > 0 ? _tempoRestante / _tempoTotal : 0.0;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text('Tempo de Descanso', style: AppTextStyles.titulo3()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Seletor de duração
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _opcoesTempo.map((t) {
                  final selecionado = _tempoTotal == t && !_ativo;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs / 2),
                    child: ChoiceChip(
                      label: Text('${t}s'),
                      selected: selecionado,
                      onSelected: (_) => _definirTempo(t),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Indicador circular de progresso
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final escala = _ativo
                    ? 1.0 + (_pulseController.value * 0.03)
                    : 1.0;
                return Transform.scale(scale: escala, child: child);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: _progresso,
                      strokeWidth: 10,
                      backgroundColor: AppColors.divisorClaro,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_corProgresso),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatarTempo(_tempoRestante),
                        style: AppTextStyles.destaque(cor: _corProgresso),
                      ),
                      Text(
                        _ativo ? 'descansando' : 'pronto',
                        style: AppTextStyles.corpoPequeno(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Botões de controle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pular
                _BotaoTimer(
                  icone: Icons.skip_next_rounded,
                  rotulo: 'Pular',
                  onTap: _pular,
                  tipo: _TipoBotao.secundario,
                ),

                // Play / Pause (botão principal)
                _BotaoTimer(
                  icone: _ativo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  rotulo: _ativo ? 'Pausar' : 'Iniciar',
                  onTap: _ativo ? _pausar : _iniciar,
                  tipo: _TipoBotao.primario,
                ),

                // +30 segundos
                _BotaoTimer(
                  icone: Icons.add_rounded,
                  rotulo: '+30s',
                  onTap: _adicionarTrinta,
                  tipo: _TipoBotao.secundario,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Reiniciar
            TextButton.icon(
              onPressed: _reiniciar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Reiniciar', style: AppTextStyles.label()),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

enum _TipoBotao { primario, secundario }

class _BotaoTimer extends StatelessWidget {
  const _BotaoTimer({
    required this.icone,
    required this.rotulo,
    required this.onTap,
    required this.tipo,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  final _TipoBotao tipo;

  @override
  Widget build(BuildContext context) {
    if (tipo == _TipoBotao.primario) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 22),
        label: Text(rotulo),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 20),
      label: Text(rotulo),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm + 2),
      ),
    );
  }
}
