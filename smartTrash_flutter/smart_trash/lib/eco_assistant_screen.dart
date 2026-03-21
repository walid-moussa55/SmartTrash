import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:naqi_ai/app_theme.dart';
import 'package:naqi_ai/app_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatMessage {
  final String text;
  final bool isUser;
  final Key key;

  ChatMessage({required this.text, required this.isUser})
      : key = UniqueKey();
}

class EcoAssistantScreen extends StatefulWidget {
  const EcoAssistantScreen({super.key});

  @override
  State<EcoAssistantScreen> createState() => _EcoAssistantScreenState();
}

class _EcoAssistantScreenState extends State<EcoAssistantScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final AppSettings _appSettings = AppSettings();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAiTyping = false;

  final List<Map<String, String>> _chatHistory = [];

  late AnimationController _pulseController;
  late AnimationController _dotsController;

  final String _systemPrompt = """Tu es l'Eco-Assistant de l'application NaqiAI. 
Tu parles français. Ton but est d'aider les citoyens à mieux trier leurs déchets, 
à comprendre l'importance du recyclage, et à protéger l'environnement de leur ville. 
Les poubelles de la ville acceptent : Plastique, Verre, Papier/Carton, Organique, et Électronique. 
Si la personne demande comment jeter un objet, dis-lui dans quelle poubelle le mettre. 
Sois concis, très amical. Utilise des emojis. Ne réponds pas aux questions hors sujet 
(hors écologie/recyclage/déchets).""";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _dotsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _initSpeech();
    _initChat();
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_textController.text.trim().isNotEmpty) {
                _sendMessage(_textController.text.trim());
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Speech error: ${errorNotification.errorMsg}");
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  void _initChat() {
    _chatHistory.add({"role": "system", "content": _systemPrompt});
    _addMessage(
      "Bonjour ! 🌿 Je suis votre Eco-Assistant NaqiAI. "
      "Demandez-moi comment trier un déchet, ou appuyez sur le micro pour me parler !",
      false,
    );
  }

  void _addMessage(String text, bool isUser) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _addMessage(text, true);
    _textController.clear();
    _chatHistory.add({"role": "user", "content": text});

    setState(() => _isAiTyping = true);

    try {
      final serverUrl = _appSettings.rotageServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) {
        _addMessage("Erreur : URL du serveur non configurée.", false);
        return;
      }

      final response = await http.post(
        Uri.parse('$serverUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"messages": _chatHistory}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.containsKey('reply')) {
          String aiResponse = data['reply'];
          _addMessage(aiResponse, false);
          _chatHistory.add({"role": "assistant", "content": aiResponse});
        } else {
          _addMessage("Désolé, je n'ai pas pu formuler de réponse.", false);
        }
      } else {
        String errorMsg = "Erreur serveur (Code ${response.statusCode}).";
        try {
          final Map<String, dynamic> errData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errData.containsKey('detail')) errorMsg = "⚠️ ${errData['detail']}";
        } catch (_) {}
        _addMessage(errorMsg, false);
      }
    } catch (e) {
      _addMessage("Connexion refusée. Assurez-vous que le serveur NaqiAI est lancé.", false);
      debugPrint("Chat error: $e");
    } finally {
      if (mounted) setState(() => _isAiTyping = false);
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage(_textController.text.trim());
      }
      return;
    }

    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission micro refusée. Activez-la dans les paramètres.")),
          );
        }
        return;
      }
    }

    if (!_speechAvailable) _speechAvailable = await _speech.initialize();

    if (_speechAvailable) {
      setState(() => _isListening = true);
      _textController.clear();
      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() => _textController.text = val.recognizedWords);
            if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
              setState(() => _isListening = false);
              _speech.stop();
              _sendMessage(val.recognizedWords.trim());
            }
          }
        },
        localeId: 'fr_FR',
        listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reconnaissance vocale non disponible sur cet appareil.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withAlpha(180)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eco-Assistant', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Powered by Mistral AI', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                : [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _AnimatedChatBubble(
                    key: msg.key,
                    text: msg.text,
                    isUser: msg.isUser,
                    theme: theme,
                  );
                },
              ),
            ),
            if (_isAiTyping) _buildTypingIndicator(theme),
            _buildInputArea(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _dotsController,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? AppTheme.darkCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_dotsController.value + i * 0.25) % 1.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.translate(
                      offset: Offset(0, -4 * math.sin(phase * math.pi)),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withAlpha((120 + 135 * math.sin(phase * math.pi)).toInt()),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice Input Button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isListening ? 1.0 + 0.08 * math.sin(_pulseController.value * math.pi) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? LinearGradient(colors: [AppTheme.accentRed, AppTheme.accentRed.withAlpha(180)])
                        : null,
                    color: _isListening ? null : (isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? AppTheme.accentRed.withAlpha(100) : AppTheme.primaryPurple.withAlpha(60),
                      width: 2,
                    ),
                    boxShadow: _isListening
                        ? [BoxShadow(color: AppTheme.accentRed.withAlpha(80), blurRadius: 15, spreadRadius: 2)]
                        : [],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : AppTheme.primaryPurple,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryPurple.withAlpha(30)),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: _isListening ? "🎤 Je vous écoute..." : "Demandez comment trier...",
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send Button
            GestureDetector(
              onTap: () => _sendMessage(_textController.text),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withAlpha(180)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryPurple.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated chat bubble that slides in from left/right
class _AnimatedChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final ThemeData theme;

  const _AnimatedChatBubble({
    required super.key,
    required this.text,
    required this.isUser,
    required this.theme,
  });

  @override
  State<_AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<_AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: widget.isUser
                  ? LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.primaryPurple.withAlpha(200)])
                  : null,
              color: widget.isUser ? null : (widget.theme.cardTheme.color ?? AppTheme.darkCard),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: widget.isUser ? const Radius.circular(18) : const Radius.circular(4),
                bottomRight: widget.isUser ? const Radius.circular(4) : const Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isUser ? AppTheme.primaryPurple : Colors.black).withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.isUser ? Colors.white : (widget.theme.textTheme.bodyLarge?.color ?? Colors.white),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
