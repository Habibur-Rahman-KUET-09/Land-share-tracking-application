import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../services/migration_service.dart';
import '../../services/user_directory.dart';
import '../../theme/app_theme.dart';
import '../../utils/byte_share.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/kistify_app_bar.dart';

/// Brings a group's pre-app history in from a spreadsheet.
///
/// Deliberately three steps — download a filled-in sample, upload, then
/// review what *would* happen before anything is written. A bulk write into
/// a money ledger is not something to fire off from a single tap, and the
/// preview is what makes a wrong column or a misspelled name visible while
/// it is still cheap to fix.
class MigrationScreen extends StatefulWidget {
  final LandGroup group;
  const MigrationScreen({super.key, required this.group});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  List<GroupMember> _members = const [];
  Map<String, String> _names = const {};
  MigrationPreview? _preview;
  bool _busy = false;
  String? _error;
  int? _imported;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await GroupService().watchMembers(widget.group.id).first;
    final names = await UserDirectory.instance.names(members.map((m) => m.uid));
    if (!mounted) return;
    setState(() {
      _members = members;
      _names = names;
    });
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final bytes = MigrationService.buildTemplate(members: _members, memberNames: _names);
      await shareBytes(
        bytes: bytes,
        filename: '${widget.group.name} — মাইগ্রেশন ফরম্যাট.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        text: S.t(context, 'migration_template'),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndParse() async {
    setState(() {
      _busy = true;
      _error = null;
      _imported = null;
    });
    try {
      // withData: the web has no file path to read back from, so the bytes
      // have to come along with the pick.
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final existing = await ContributionService().watchGroupContributions(widget.group.id).first;
      final preview = MigrationService.parse(
        bytes: Uint8List.fromList(bytes),
        members: _members,
        memberNames: _names,
        existing: existing,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
      final count = await MigrationService().import(
        groupId: widget.group.id,
        preview: preview,
        importedBy: uid,
      );
      if (!mounted) return;
      setState(() {
        _imported = count;
        _preview = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'data_migration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            S.t(context, 'migration_intro'),
            style: const TextStyle(fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 20),

          _Step(
            number: 1,
            title: S.t(context, 'migration_step_download'),
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _downloadTemplate,
              icon: const Icon(Icons.download_outlined),
              label: Text(S.t(context, 'migration_template')),
            ),
          ),
          _Step(
            number: 2,
            title: S.t(context, 'migration_step_fill'),
            child: Text(
              S.t(context, 'migration_columns'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.mutedText, height: 1.6),
            ),
          ),
          _Step(
            number: 3,
            title: S.t(context, 'migration_step_upload'),
            child: FilledButton.icon(
              onPressed: _busy ? null : _pickAndParse,
              icon: const Icon(Icons.upload_file),
              label: Text(S.t(context, 'migration_pick_file')),
            ),
          ),

          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],

          if (_imported != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.approvedBg,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.approvedFg),
                title: Text(
                  '${_imported!} ${S.t(context, 'migration_done')}',
                  style: const TextStyle(color: AppColors.approvedFg, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          if (preview != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(S.t(context, 'migration_preview'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _Summary(
              label: S.t(context, 'migration_will_import'),
              value: '${preview.importable.length}',
              amount: preview.total,
              color: AppColors.approvedFg,
            ),
            if (preview.duplicates.isNotEmpty)
              _Summary(
                label: S.t(context, 'migration_duplicates'),
                value: '${preview.duplicates.length}',
                color: AppColors.pendingFg,
              ),
            if (preview.failed.isNotEmpty)
              _Summary(
                label: S.t(context, 'migration_errors'),
                value: '${preview.failed.length}',
                color: AppColors.rejectedFg,
              ),
            if (preview.failed.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final r in preview.failed.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${S.t(context, 'migration_row')} ${r.rowNumber}: ${r.rawMember} — ${r.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.rejectedFg),
                  ),
                ),
              if (preview.failed.length > 20)
                Text(
                  '… +${preview.failed.length - 20}',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || preview.importable.isEmpty ? null : _import,
                icon: const Icon(Icons.save_alt),
                label: Text('${S.t(context, 'migration_confirm')} (${preview.importable.length})'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;
  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.primary,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final double? amount;
  final Color color;
  const _Summary({required this.label, required this.value, this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            amount == null ? value : '$value · ${CurrencyFormatter.format(amount!)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
