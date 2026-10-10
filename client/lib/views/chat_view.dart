import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/chat_policy.dart';
import '../services/waste_api.dart';
import '../services/voice_service.dart';
import '../widgets/mode_badge.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.api,
    required this.host,
    required this.token,
    required this.mode,
    required this.history,
    required this.onModeChanged,
    required this.onMessages,
    required this.onOpenSettings,
    required this.onBusyChanged,
    required this.voice,
    required this.autoSpeak,
  });

  final WasteApi api;
  final String host;
  final String? token;
  final String mode;
  final List<ChatMessage> history;
  final Future<void> Function(String) onModeChanged;
  final Future<void> Function(ChatMessage, ChatMessage) onMessages;
  final VoidCallback onOpenSettings;
  final ValueChanged<bool> onBusyChanged;
  final VoiceService voice;
  final bool autoSpeak;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;
  String? _voiceError;

  @override
  void dispose() {
    widget.voice.stopListening();
    widget.voice.stop();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final rawText = _composer.text;
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    try {
      ChatRequestPolicy.validateMessage(text);
    } on ChatRequestPolicyException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _error = 'Pair this client in Settings before sending chat.');
      return;
    }
    // Snapshot all request inputs before awaiting: mode and token may change
    // elsewhere while the provider is warming up.
    final requestMode = widget.mode;
    final requestHost = widget.host;
    final requestToken = widget.token!;
    final requestHistory = ChatRequestPolicy.historyForRequest(
      widget.history,
      requestMode,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    final user = ChatMessage(
      role: 'user',
      content: text,
      mode: requestMode,
      createdAt: DateTime.now(),
    );
    try {
      final result = await widget.api.chat(
        baseUrl: requestHost,
        token: requestToken,
        message: text,
        mode: requestMode,
        history: requestHistory,
      );
      final reply = result['reply'] as String?;
      if (reply == null || reply.trim().isEmpty) {
        throw const WasteApiException('The companion returned no reply. No message was invented.');
      }
      final assistant = ChatMessage(
        role: 'assistant',
        content: reply,
        mode: requestMode,
        createdAt: DateTime.now(),
      );
      await widget.onMessages(user, assistant);
      if (widget.autoSpeak) await _speak(assistant.content);
      // Only clear the submitted text. Preserve anything typed while waiting.
      if (mounted && _composer.text == rawText) _composer.clear();
    } on WasteApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ChatRequestPolicyException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      widget.onBusyChanged(false);
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _speak(String text) async {
    widget.voice.clearError();
    await widget.voice.speak(text);
    if (mounted && widget.voice.error != null) {
      setState(() => _voiceError = widget.voice.error);
    }
  }

  Future<void> _toggleListening() async {
    if (widget.voice.isListening) {
      await widget.voice.stopListening();
      if (mounted) setState(() {});
      return;
    }
    widget.voice.clearError();
    await widget.voice.startListening((transcript, _) {
      if (!mounted) return;
      setState(() => _composer.text = transcript);
    });
    if (mounted) {
      setState(() => _voiceError = widget.voice.error);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Conversation', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('A private bridge to your local companion.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
            ])),
            ModeBadge(mode: widget.mode),
            const SizedBox(width: 10),
            IconButton(tooltip: 'Connection settings', onPressed: widget.onOpenSettings, icon: const Icon(Icons.tune)),
          ]),
          const SizedBox(height: 18),
          _modeSelector(context),
          const SizedBox(height: 14),
          Expanded(child: widget.history.isEmpty ? _emptyState(context) : _messages(context)),
           if (_error != null) _errorBanner(context),
          if (_voiceError != null) _voiceErrorBanner(context),
          const SizedBox(height: 10),
          _composerRow(context),
        ]),
      );

  Widget _modeSelector(BuildContext context) => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'offline', label: Text('Offline'), icon: Icon(Icons.lan_outlined)),
          ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.cloud_outlined)),
        ],
        selected: {widget.mode},
        onSelectionChanged: (value) => widget.onModeChanged(value.first),
      );

  Widget _emptyState(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.forum_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                Text('Start with a clear mode', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Offline and online are explicit. WASTE never falls back to a cloud provider or makes up a reply when the companion is unavailable.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
        ),
      );

  Widget _messages(BuildContext context) => ListView.builder(
        controller: _scroll,
        itemCount: widget.history.length,
        itemBuilder: (context, index) {
          final message = widget.history[index];
          final mine = message.role == 'user';
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: mine ? Theme.of(context).colorScheme.primary.withOpacity(.15) : const Color(0xff191c2a),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: mine ? Theme.of(context).colorScheme.primary.withOpacity(.3) : Colors.white10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(children: [Text(mine ? 'YOU' : 'WASTE', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1, color: mine ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary)), const Spacer(), if (!mine) IconButton(tooltip: 'Speak reply', onPressed: () => _speak(message.content), icon: const Icon(Icons.volume_up_outlined, size: 19)), ModeBadge(mode: message.mode)]),
                  const SizedBox(height: 8),
                  SelectableText(message.content),
                ]),
              ),
            ),
          );
        },
      );

  Widget _errorBanner(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)))]),
      );

  Widget _voiceErrorBanner(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(Icons.mic_off_outlined, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 8), Expanded(child: Text(_voiceError!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))), IconButton(onPressed: () => setState(() => _voiceError = null), icon: const Icon(Icons.close))]),
      );

  Widget _composerRow(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: _composer, minLines: 1, maxLines: 5, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Message the companion…'))),
         IconButton(tooltip: widget.voice.isListening ? 'Stop listening' : 'Push to talk', onPressed: _toggleListening, icon: Icon(widget.voice.isListening ? Icons.stop_circle_outlined : Icons.mic_none_outlined)),
         const SizedBox(width: 2),
         const SizedBox(width: 10),
        FilledButton(onPressed: _sending ? null : _send, style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)), child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward)),
      ]);
}
