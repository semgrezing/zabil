import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../models/update_info.dart';
import '../providers/update_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_dimensions.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';

/// Полноэкранный блокирующий экран принудительного обновления.
///
/// Показывается когда `/update` вернул `mandatory=true`. Пользователь
/// не может закрыть/пропустить — только обновить или выйти из приложения
/// (через системный backstack).
class ForceUpdateScreen extends ConsumerWidget {
  final UpdateInfo info;

  const ForceUpdateScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(updateProgressProvider);
    final isDownloading = progress.fraction > 0 && progress.fraction < 1;
    final hasError = progress.error != null;

    return PopScope(
      canPop: false, // нельзя свайпом/back закрыть
      child: Scaffold(
        backgroundColor: AppColors.bg1,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Header
                Icon(
                  hasError
                      ? SolarIconsBold.dangerCircle
                      : SolarIconsBold.altArrowDown,
                  size: 64,
                  color: hasError ? AppColors.negative : AppColors.white,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  hasError
                      ? 'Не удалось обновить'
                      : '🎉 Доступно обновление',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.titleWhite,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasError
                      ? 'Проверьте интернет и попробуйте ещё раз.'
                      : 'Версия ${info.latestVersion}. Эта версия обязательна для продолжения работы.',
                  style: AppTypography.body.copyWith(color: AppColors.fgSoft),
                  textAlign: TextAlign.center,
                ),

                if (info.notes != null && info.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Text(
                      info.notes!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Progress / status
                if (isDownloading || progress.isInstalling) ...[
                  _ProgressBlock(progress: progress),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Actions
                AppButton(
                  label: hasError
                      ? 'Повторить'
                      : isDownloading
                          ? 'Скачивание...'
                          : progress.isInstalling
                              ? 'Установка...'
                              : 'Обновить сейчас',
                  isLoading: isDownloading || progress.isInstalling,
                  onPressed: (isDownloading || progress.isInstalling)
                      ? null
                      : () => ref
                          .read(updateProgressProvider.notifier)
                          .downloadAndInstall(info),
                ),

                if (hasError) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    progress.error ?? '',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.negative),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final UpdateProgress progress;

  const _ProgressBlock({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction * 100).clamp(0, 100).round();
    final mb = progress.received / 1024 / 1024;
    final totalMb = progress.total / 1024 / 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.isInstalling ? null : progress.fraction,
            minHeight: 8,
            backgroundColor: AppColors.bg2,
            valueColor: const AlwaysStoppedAnimation(AppColors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progress.isInstalling
                  ? 'Подготовка к установке...'
                  : '${mb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.fgSoft),
            ),
            if (!progress.isInstalling)
              Text(
                '$percent%',
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.titleWhite),
              ),
          ],
        ),
      ],
    );
  }
}
