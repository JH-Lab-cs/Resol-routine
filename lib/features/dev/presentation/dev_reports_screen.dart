import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/io/limited_utf8_reader.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../../core/ui/components/skeleton.dart';
import '../../report/application/report_providers.dart';
import '../../report/data/shared_reports_repository.dart';
import '../../report/presentation/parent_shared_report_detail_screen.dart';
import '../../report/presentation/student_report_screen.dart';
import '../../settings/application/user_settings_providers.dart';

class DevReportsScreen extends ConsumerStatefulWidget {
  const DevReportsScreen({super.key});

  @override
  ConsumerState<DevReportsScreen> createState() => _DevReportsScreenState();
}

class _DevReportsScreenState extends ConsumerState<DevReportsScreen> {
  bool _isImporting = false;
  bool _isDeletingAll = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('개발자 리포트')),
      body: AppPageBody(
        child: settingsAsync.when(
          loading: () => const _DevReportsLoading(),
          error: (error, _) => Center(
            child: Text(
              '${AppCopyKo.loadFailed('개발자 리포트')}\n$error',
              textAlign: TextAlign.center,
            ),
          ),
          data: (settings) {
            if (settings.role == 'PARENT') {
              return _buildParentView(context);
            }
            return _buildStudentView(settings.track);
          },
        ),
      ),
    );
  }

  Widget _buildStudentView(String track) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('학생 리포트 테스트', style: AppTypography.section),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '파일 공유 및 리포트 UI를 디버깅할 때 사용합니다.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey<String>('dev-report-open-student'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => StudentReportScreen(track: track),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('리포트 열기'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParentView(BuildContext context) {
    final summariesAsync = ref.watch(sharedReportSummariesProvider);
    final isBusy = _isImporting || _isDeletingAll;

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('dev-report-import-button'),
                onPressed: isBusy ? null : _importReportFile,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined),
                label: const Text('JSON 가져오기'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('dev-report-delete-all-button'),
                onPressed: isBusy ? null : _deleteAllReports,
                icon: _isDeletingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
                label: const Text('전체 삭제'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '파일 기반 리포트 디버깅 전용 메뉴입니다.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        summariesAsync.when(
          loading: () => const _DevReportsLoading(),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${AppCopyKo.loadFailed('가져온 리포트')}\n$error',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          data: (summaries) {
            if (summaries.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(AppCopyKo.emptyImportedReports),
                ),
              );
            }

            return Column(
              key: const ValueKey<String>('dev-reports-list'),
              children: [
                for (final summary in summaries) ...[
                  Card(
                    child: ListTile(
                      key: ValueKey<String>('dev-report-item-${summary.id}'),
                      onTap: () => _openDetail(summary.id),
                      title: Text(
                        '${summary.studentDisplayName ?? '학생'} · ${summary.latestDayKey ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '풀이 ${summary.totalSolvedCount} · 오답 ${summary.totalWrongCount}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '상세 보기',
                            onPressed: () => _openDetail(summary.id),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'dev-report-delete-${summary.id}',
                            ),
                            tooltip: '삭제',
                            onPressed: () => _deleteOne(summary),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _importReportFile() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
        ],
      );
      if (file == null) {
        if (mounted) {
          AppSnackbars.showCanceled(context);
        }
        return;
      }

      final maxBytes = DbTextLimits.reportImportMaxBytes;
      final maxMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);

      try {
        final lengthBytes = await file.length();
        if (lengthBytes > maxBytes) {
          if (mounted) {
            AppSnackbars.showWarning(
              context,
              AppCopyKo.importSizeExceeded(maxMb: maxMb),
            );
          }
          return;
        }
      } catch (_) {
        // Fall through to streaming guard.
      }

      final payload = await LimitedUtf8Reader.read(
        file.openRead(),
        maxBytes: maxBytes,
        path: 'importFile',
      );

      if (payload.isEmpty) {
        throw const FormatException('리포트 파일이 비어 있습니다.');
      }

      await ref
          .read(sharedReportsRepositoryProvider)
          .importFromJson(source: file.name, payloadJson: payload);
      ref.invalidate(sharedReportSummariesProvider);

      if (mounted) {
        AppSnackbars.showSuccess(context, AppCopyKo.reportImportSuccess);
      }
    } on FormatException {
      if (mounted) {
        AppSnackbars.showWarning(context, AppCopyKo.reportImportInvalid);
      }
    } catch (error) {
      if (mounted) {
        AppSnackbars.showError(
          context,
          '${AppCopyKo.reportImportFailed}\n$error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _deleteAllReports() async {
    final summaries = await ref.read(sharedReportSummariesProvider.future);
    if (!mounted) {
      return;
    }
    if (summaries.isEmpty) {
      AppSnackbars.showWarning(context, AppCopyKo.emptyImportedReports);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('전체 삭제'),
          content: const Text('가져온 리포트를 모두 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeletingAll = true;
    });
    try {
      final repository = ref.read(sharedReportsRepositoryProvider);
      for (final summary in summaries) {
        await repository.deleteById(summary.id);
        ref.invalidate(sharedReportByIdProvider(summary.id));
      }
      ref.invalidate(sharedReportSummariesProvider);
      if (mounted) {
        AppSnackbars.showSuccess(context, AppCopyKo.reportDeleteSuccess);
      }
    } catch (error) {
      if (mounted) {
        AppSnackbars.showError(
          context,
          '${AppCopyKo.reportDeleteFailed}\n$error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAll = false;
        });
      }
    }
  }

  Future<void> _deleteOne(SharedReportSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('리포트 삭제'),
          content: Text('${summary.source} 리포트를 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final deleted = await ref
          .read(sharedReportsRepositoryProvider)
          .deleteById(summary.id);
      ref.invalidate(sharedReportSummariesProvider);
      ref.invalidate(sharedReportByIdProvider(summary.id));
      if (!mounted) {
        return;
      }
      if (deleted) {
        AppSnackbars.showSuccess(context, AppCopyKo.reportDeleteSuccess);
      } else {
        AppSnackbars.showWarning(context, AppCopyKo.reportDeleteAlready);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackbars.showError(
        context,
        '${AppCopyKo.reportDeleteFailed}\n$error',
      );
    }
  }

  void _openDetail(int reportId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ParentSharedReportDetailScreen(sharedReportId: reportId),
      ),
    );
  }
}

class _DevReportsLoading extends StatelessWidget {
  const _DevReportsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonCard(
          child: SizedBox(
            height: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkeletonLine(width: 180),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        SkeletonCard(
          child: SizedBox(
            height: 72,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkeletonLine(width: 220),
            ),
          ),
        ),
      ],
    );
  }
}
