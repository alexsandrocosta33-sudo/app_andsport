import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroExercicioPage extends StatefulWidget {
  const CadastroExercicioPage({Key? key}) : super(key: key);

  @override
  State<CadastroExercicioPage> createState() => _CadastroExercicioPageState();
}

class _CadastroExercicioPageState extends State<CadastroExercicioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _grupoController = TextEditingController();
  final _videoUrlController = TextEditingController();

  bool _estaCarregando = false;

  Future<void> _salvarExercicio() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _estaCarregando = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('exercicios').doc();

      await docRef.set({
        'id': docRef.id,
        'nome': _nomeController.text.trim(),
        'grupoMuscular': _grupoController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(),
        'criadoEm': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercício cadastrado com sucesso!')),
      );

      _nomeController.clear();
      _grupoController.clear();
      _videoUrlController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar exercício: $e')));
    } finally {
      setState(() {
        _estaCarregando = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _grupoController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Exercício'), centerTitle: true),
      body: _estaCarregando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Salvando exercício no banco...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Exercício',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Insira o nome do exercício'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _grupoController,
                      decoration: const InputDecoration(
                        labelText: 'Grupo Muscular (ex: Peito, Pernas)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.accessibility_new),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Insira o grupo muscular'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _videoUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link do Vídeo Demonstrativo (YouTube)',
                        hintText: 'https://www.youtube.com/watch?v=...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.video_library,
                          color: Colors.red,
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('youtube.com') &&
                              !value.contains('youtu.be')) {
                            return 'Por favor, insira um link válido do YouTube';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _salvarExercicio,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.vertical(16),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: const Text(
                        'Salvar Exercício',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
