import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Tela de onboarding exibida apenas na primeira abertura do app.
/// Ao concluir, salva 'onboarding_concluido: true' nas SharedPreferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _paginaAtual = 0;
  String? _objetivoSelecionado;

  static const _objetivos = [
    'Emagrecer',
    'Ganhar massa',
    'Condicionamento',
    'Saúde geral',
  ];

  Future<void> _concluirOnboarding() async {
    if (_paginaAtual == 3 && _objetivoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um objetivo para continuar.'),
          backgroundColor: AppColors.acento,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_concluido', true);
    if (_objetivoSelecionado != null) {
      await prefs.setString('objetivo_selecionado', _objetivoSelecionado!);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _avancar() {
    if (_paginaAtual < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _concluirOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaria,
      body: SafeArea(
        child: Column(
          children: [
            // Botão pular (visível nas primeiras 3 páginas)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                    right: AppSpacing.md, top: AppSpacing.sm),
                child: TextButton(
                  onPressed: _paginaAtual < 3 ? _concluirOnboarding : null,
                  child: Text(
                    _paginaAtual < 3 ? 'Pular' : '',
                    style: AppTextStyles.label(cor: Colors.white70),
                  ),
                ),
              ),
            ),

            // Páginas de conteúdo
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _paginaAtual = i),
                children: [
                  _PaginaOnboarding(
                    icone: Icons.fitness_center_rounded,
                    titulo: 'Bem-vindo ao\nAndSport!',
                    descricao:
                        'Sua academia na palma da mão.\nTreinos personalizados, evolução real.',
                  ),
                  _PaginaOnboarding(
                    icone: Icons.assignment_turned_in_rounded,
                    titulo: 'Registre seus\ntreinos',
                    descricao:
                        'Anote cada exercício, série e carga.\nAcompanhe sua progressão com dados reais.',
                  ),
                  _PaginaOnboarding(
                    icone: Icons.show_chart_rounded,
                    titulo: 'Veja sua\nevolução',
                    descricao:
                        'Gráficos de progresso que mostram\nexatamente o quanto você cresceu.',
                  ),
                  _PaginaObjetivo(
                    objetivos: _objetivos,
                    objetivoSelecionado: _objetivoSelecionado,
                    onSelecionado: (obj) =>
                        setState(() => _objetivoSelecionado = obj),
                  ),
                ],
              ),
            ),

            // Indicadores de progresso
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _paginaAtual == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paginaAtual == i
                        ? AppColors.acento
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Botão avançar / concluir
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _avancar,
                  child: Text(_paginaAtual < 3 ? 'Próximo' : 'Começar agora'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PaginaOnboarding extends StatelessWidget {
  const _PaginaOnboarding({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.acento.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.acento.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(icone, size: 64, color: AppColors.acento),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            titulo,
            style: AppTextStyles.titulo1(cor: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            descricao,
            style: AppTextStyles.corpo(cor: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PaginaObjetivo extends StatelessWidget {
  const _PaginaObjetivo({
    required this.objetivos,
    required this.objetivoSelecionado,
    required this.onSelecionado,
  });

  final List<String> objetivos;
  final String? objetivoSelecionado;
  final ValueChanged<String> onSelecionado;

  static const _icones = {
    'Emagrecer': Icons.local_fire_department_rounded,
    'Ganhar massa': Icons.sports_gymnastics,
    'Condicionamento': Icons.directions_run_rounded,
    'Saúde geral': Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Qual é seu\nobjetivo? 🎯',
            style: AppTextStyles.titulo1(cor: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...objetivos.map((obj) {
            final selecionado = objetivoSelecionado == obj;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: GestureDetector(
                onTap: () => onSelecionado(obj),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? AppColors.acento
                        : Colors.white.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: selecionado
                          ? AppColors.acento
                          : Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _icones[obj] ?? Icons.star,
                        color: selecionado
                            ? Colors.white
                            : AppColors.acento,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        obj,
                        style: AppTextStyles.titulo3(cor: Colors.white),
                      ),
                      const Spacer(),
                      if (selecionado)
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
