import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/reports/report_chat_message.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';

/// Per-report discussion thread (server: `GET/POST /reports/:id/chat/messages`).
class ReportChatScreen extends StatefulWidget {
  const ReportChatScreen({
    super.key,
    required this.reportId,
  });

  final int reportId;

  @override
  State<ReportChatScreen> createState() => _ReportChatScreenState();
}

class _ReportChatScreenState extends State<ReportChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<ReportChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = getIt<ReportRepository>();
      final list = await repo.getReportChatMessages(widget.reportId);
      if (!mounted) return;
      setState(() {
        _messages = list.reversed.toList();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final repo = getIt<ReportRepository>();
      final msg = await repo.postReportChatMessage(widget.reportId, text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report #${widget.reportId} chat'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final name =
                              (m.username != null && m.username!.isNotEmpty)
                                  ? m.username!
                                  : 'Wazer';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(m.content),
                              isThreeLine: m.content.length > 40,
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask if it is still there…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      shape: const CircleBorder(),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
