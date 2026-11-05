import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';

const ageMajorityConfirmation =
    'I confirm I am 18 years or older (or the age of majority in my country).';

const accountProofInstruction =
    'Please blur out or crop your transaction history, account balance, and home address before uploading. We only require visibility of your Full Name and Account Number to verify your profile.';

const accountProofMaxBytes = 4 * 1024 * 1024;

class AgeMajorityCheckbox extends StatelessWidget {
  const AgeMajorityCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        ageMajorityConfirmation,
        style: TextStyle(fontSize: 13, height: 1.35),
      ),
    );
  }
}

class AccountProofFile {
  const AccountProofFile({required this.path, required this.name});

  final String path;
  final String name;
}

Future<String?> accountProofRejection(PlatformFile file) async {
  final extension = (file.extension ?? '').toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'pdf'}.contains(extension)) {
    return 'Upload a JPG, PNG, or PDF.';
  }
  final size = file.lengthSync() ?? await file.length();
  if (size == null || size > accountProofMaxBytes) {
    return 'Account proof must be 4 MB or smaller.';
  }
  if (file.path == null || file.path!.isEmpty) {
    return 'Could not read the selected file.';
  }
  return null;
}

Future<AccountProofFile?> pickAccountProof() async {
  // file_picker 13+: pickFiles returns List<PlatformFile> (empty if cancelled).
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (files.isEmpty) {
    return null;
  }
  final file = files.first;
  final rejection = await accountProofRejection(file);
  if (rejection != null) {
    throw FormatException(rejection);
  }
  return AccountProofFile(path: file.path!, name: file.name);
}

class AccountProofUpload extends StatelessWidget {
  const AccountProofUpload({
    required this.fileName,
    required this.onPick,
    super.key,
  });

  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload Proof of Account',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          accountProofInstruction,
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onPick,
          child: Container(
            height: 120,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: context.pelevo.border),
              borderRadius: PelevoRadii.card,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_outlined),
                const SizedBox(height: 7),
                Text(fileName ?? 'Tap to upload'),
                Text(
                  'PNG, JPG or PDF (Max 4MB)',
                  style: TextStyle(color: context.pelevo.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
