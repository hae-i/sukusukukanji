import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/content_layout.dart';

class IconSelectionScreen extends StatelessWidget {
  const IconSelectionScreen({super.key, required this.controller});
  final AppController controller;
  Future<void> _select(BuildContext context, String key) async {
    try {
      final applied = await controller.selectIcon(key);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              applied
                  ? '앱 아이콘을 바꿨어요.'
                  : '선택을 저장했어요. 이 환경에서는 기기 아이콘 변경을 지원하지 않아요.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.iconError ?? '아이콘 변경에 실패했어요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('앱 아이콘')),
      body: SafeArea(
        child: ContentLayout(
          children: [
            const Text('한 학년씩 자라며 새로운 아이콘이 열려요.\n해금한 아이콘은 직접 골라 사용할 수 있어요.'),
            const SizedBox(height: 24),
            if (controller.iconError != null) Text(controller.iconError!),
            for (final grade in controller.catalog!.grades) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/${grade.iconKey}.png',
                      width: 56,
                      height: 56,
                      excludeFromSemantics: true,
                    ),
                  ),
                  title: Text('${grade.nameKo} ${grade.stageNameKo}'),
                  subtitle: Text(
                    !controller.settings.icons.unlockedIcons.contains(
                          grade.iconKey,
                        )
                        ? '잠김'
                        : controller.settings.icons.selectedIcon ==
                              grade.iconKey
                        ? '선택됨'
                        : '해금됨',
                  ),
                  trailing: Icon(
                    !controller.settings.icons.unlockedIcons.contains(
                          grade.iconKey,
                        )
                        ? Icons.lock_outline
                        : controller.settings.icons.selectedIcon ==
                              grade.iconKey
                        ? Icons.check_circle_outline
                        : Icons.chevron_right,
                  ),
                  onTap:
                      controller.changingIcon ||
                          !controller.settings.icons.unlockedIcons.contains(
                            grade.iconKey,
                          )
                      ? null
                      : () => _select(context, grade.iconKey),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
}
