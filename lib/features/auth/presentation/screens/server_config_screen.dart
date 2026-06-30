import 'package:flutter/material.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key, this.onConfigSaved});

  final VoidCallback? onConfigSaved;

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _endpointController;
  late TextEditingController _projectIdController;
  
  bool _isTesting = false;
  bool _isSaving = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _projectIdController = TextEditingController();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final endpoint = await AppwriteService.getSavedEndpoint();
    final projectId = await AppwriteService.getSavedProjectId();
    setState(() {
      _endpointController.text = endpoint;
      _projectIdController.text = projectId;
    });
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final success = await AppwriteService.testConnection(
      _endpointController.text.trim(),
      _projectIdController.text.trim(),
    );

    setState(() {
      _isTesting = false;
      _isSuccess = success;
      _statusMessage = success
          ? 'Connection successful!'
          : 'Connection failed. Please check your settings.';
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    final success = await AppwriteService.testConnection(
      _endpointController.text.trim(),
      _projectIdController.text.trim(),
    );

    if (success) {
      await AppwriteService.saveConfig(
        _endpointController.text.trim(),
        _projectIdController.text.trim(),
      );
      if (mounted) {
        widget.onConfigSaved?.call();
      }
    } else {
      setState(() {
        _isSaving = false;
        _isSuccess = false;
        _statusMessage = 'Could not save. Connection verification failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ilithid',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Server Configuration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _endpointController,
                          labelText: 'Appwrite Endpoint',
                          hintText: 'https://example.com/v1',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Endpoint is required';
                            }
                            if (!value.startsWith('http://') && !value.startsWith('https://')) {
                              return 'Must start with http:// or https://';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _projectIdController,
                          labelText: 'Project ID',
                          hintText: 'project_id',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Project ID is required';
                            }
                            return null;
                          },
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isSuccess ? AppColors.heal : AppColors.damage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(
                          onPressed: _testConnection,
                          isLoading: _isTesting,
                          variant: AppButtonVariant.secondary,
                          child: const Text('Test Connection'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          onPressed: _saveConfig,
                          isLoading: _isSaving,
                          child: const Text('Save & Continue'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
