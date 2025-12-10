import 'package:flutter/material.dart';
import 'package:stoppr/core/streak/sharing_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class AcceptInvitePage extends StatefulWidget {
  final String token;
  final String initiatorName;
  const AcceptInvitePage({super.key, required this.token, required this.initiatorName});
  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  bool _loading = false;
  bool _error = false;

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    final ok = await SharingService.instance.respondToRequest(widget.token, accept);
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? AppLocalizations.of(context)!.translate('shareInvitation_invitationAccepted')
              : AppLocalizations.of(context)!.translate('shareInvitation_invitationDeclined'))));
      Navigator.pop(context);
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.translate('shareInvitation_title'))),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${widget.initiatorName.isNotEmpty ? widget.initiatorName : localizations.translate('prePaywall_friendFallbackName')} ${localizations.translate('shareInvitation_friendWantsToShare')}'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _respond(true),
                        child: Text(localizations.translate('shareInvitation_accept')),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () => _respond(false),
                        child: Text(localizations.translate('shareInvitation_decline')),
                      ),
                    ],
                  ),
                  if (_error)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText(localizations.translate('shareInvitation_errorProcessing'),
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
      ),
    );
  }
} 