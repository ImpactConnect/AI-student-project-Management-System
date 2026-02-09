import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:student_project_management/src/features/auth/data/auth_repository.dart';
import 'package:student_project_management/src/features/ai_assistant/domain/proposal_history.dart';
import 'package:student_project_management/src/features/ai_assistant/data/proposal_history_repository.dart';
import 'package:student_project_management/src/features/projects/data/ai_service.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/utils/document_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final _titleController = TextEditingController();
  final _objectivesController = TextEditingController();
  bool _isChecking = false;
  bool _isAnalyzing = false;
  bool _isExporting = false;
  String? _selectedFileName;
  Map<String, dynamic>? _analysisResult;

  Future<void> _pickAndUploadDocument() async {
    setState(() => _isAnalyzing = true);
    print('Starting document upload...');
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        String? path;
        Uint8List? fileBytes;
        String fileName = result.files.single.name;

        if (kIsWeb) {
          fileBytes = result.files.single.bytes;
        } else {
          path = result.files.single.path;
          if (path != null) {
            final file = File(path);
            fileBytes = await file.readAsBytes();
          }
        }

        if (fileBytes == null) return;

        _selectedFileName = fileName;
        setState(() {});

        String extractedText = '';
        if (fileName.toLowerCase().endsWith('.pdf')) {
          print('Extracting PDF text...');
          try {
            extractedText = await DocumentParser.extractTextFromPdf(fileBytes);
            print('PDF text length: ${extractedText.length}');
          } catch (e) {
            print('PDF Extraction failed: $e');
          }
        } else {
          print('Reading file as string...');
          try {
            extractedText = String.fromCharCodes(fileBytes);
          } catch (e) {
            print('File read error: $e');
            if (fileName.toLowerCase().endsWith('.docx') ||
                fileName.toLowerCase().endsWith('.doc')) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'DOCX files not fully supported. Try PDF or TXT.',
                    ),
                  ),
                );
              }
            }
          }
        }

        if (extractedText.isNotEmpty && extractedText.length > 50) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analyzing document...')),
            );
          }

          print('Calling extractProjectDetails...');
          try {
            final aiService = await ref.read(aiServiceProvider.future);
            final aiData = await aiService.extractProjectDetails(extractedText);
            print('Extraction complete: $aiData');

            if (mounted) {
              setState(() {
                if (aiData.containsKey('title'))
                  _titleController.text = aiData['title'];
                if (aiData.containsKey('objectives'))
                  _objectivesController.text = aiData['objectives'];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Auto-filled from document!')),
              );
            }
          } catch (aiErr) {
            print('AI Extraction error: $aiErr');
            throw aiErr;
          }
        } else {
          print('Context too short for AI analysis');
        }
      }
    } catch (e) {
      print('Upload process error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    } finally {
      print('Resetting analysis state');
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _checkProposal() async {
    if (_titleController.text.isEmpty || _objectivesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Title and Objectives')),
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _analysisResult = null;
    });
    print('Starting proposal check...');

    try {
      print('Fetching projects summary for context...');
      final summaryList = await ref
          .read(projectRepositoryProvider)
          .getProjectsSummary();
      print('Projects in summary: ${summaryList.length}');

      final projectsSummary = summaryList
          .map((p) {
            return "ID: ${p['id']}\nTitle: ${p['title']}\nStudent: ${p['studentName']}\nYear: ${p['year']}\nDepartment: ${p['department']}\nObjectives: ${p['objectives']}\n---\n";
          })
          .join("\n");

      print('Initializing AI Service for check...');
      final aiService = await ref.read(aiServiceProvider.future);
      print('Calling checkProposal...');
      final result = await aiService.checkProposal(
        _titleController.text,
        _objectivesController.text,
        projectsSummary.substring(
          0,
          projectsSummary.length > 20000 ? 20000 : projectsSummary.length,
        ),
      );
      print('Proposal check complete: $result');

      if (mounted) {
        setState(() => _analysisResult = result);

        // Save to history
        await _saveToHistory();
      }
    } catch (e) {
      print('Proposal check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      print('Resetting checking state');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _saveToHistory() async {
    if (_analysisResult == null) return;

    try {
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      if (currentUser == null) return;

      final history = ProposalHistory(
        id: '',
        title: _titleController.text,
        objectives: _objectivesController.text,
        supervisorId: currentUser.uid,
        createdAt: DateTime.now(),
        analysis: _analysisResult!,
      );

      await ref.read(proposalHistoryRepositoryProvider).addHistory(history);
      print('Saved to history');
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  void _loadFromHistory(ProposalHistory history) {
    setState(() {
      _titleController.text = history.title;
      _objectivesController.text = history.objectives;
      _analysisResult = history.analysis;
    });
  }

  Future<void> _exportToPdf() async {
    if (_analysisResult == null) return;

    setState(() => _isExporting = true);
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF Export not supported on Web yet.')),
      );
      if (mounted) setState(() => _isExporting = false);
      return;
    }

    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      final Size pageSize = page.getClientSize();

      double yPos = 20;
      final double maxWidth = pageSize.width;

      // Helper function to draw wrapped text
      void drawWrappedText(
        String text,
        PdfFont font, {
        PdfBrush? brush,
        double indent = 0,
      }) {
        final format = PdfStringFormat(
          lineAlignment: PdfVerticalAlignment.top,
          alignment: PdfTextAlignment.left,
        );
        format.lineSpacing = 5;

        graphics.drawString(
          text,
          font,
          bounds: Rect.fromLTWH(indent, yPos, maxWidth - indent, 0),
          format: format,
          brush: brush,
        );
        // Estimate height based on font size and text length
        final lines = (text.length / 80).ceil() + 1; // Rough estimate
        yPos += (font.height * lines) + 10;
      }

      // Title
      drawWrappedText(
        'Proposal Analysis Report',
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
      );
      yPos += 10;

      // Proposed Topic Section
      drawWrappedText(
        'Proposed Topic',
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      );

      drawWrappedText(
        'Title: ${_titleController.text}',
        PdfStandardFont(PdfFontFamily.helvetica, 11),
      );

      drawWrappedText(
        'Objectives: ${_objectivesController.text}',
        PdfStandardFont(PdfFontFamily.helvetica, 11),
      );
      yPos += 10;

      // Analysis Results
      final data = _analysisResult!;
      final matchingPct = data['matchingPercentage'] ?? 0;
      final isDuplicate = data['isDuplicate'] == true;

      drawWrappedText(
        'Analysis Results',
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      );

      drawWrappedText(
        'Overall Matching: $matchingPct%',
        PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(
          isDuplicate ? PdfColor(220, 53, 69) : PdfColor(40, 167, 69),
        ),
      );

      drawWrappedText(
        isDuplicate
            ? 'Status: Duplicate/High Similarity Detected'
            : 'Status: Topic Appears Original',
        PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(
          isDuplicate ? PdfColor(220, 53, 69) : PdfColor(40, 167, 69),
        ),
      );
      yPos += 10;

      // Matched Projects
      final matchedProjects =
          (data['matchedProjects'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (matchedProjects.isNotEmpty) {
        drawWrappedText(
          'Matched Projects (${matchedProjects.length})',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
        );

        for (var project in matchedProjects) {
          final projectText =
              '• ${project['title']} (${project['similarity']}% match)\n  Student: ${project['studentName']} | ${project['department']} | ${project['year']}';
          drawWrappedText(
            projectText,
            PdfStandardFont(PdfFontFamily.helvetica, 10),
            indent: 10,
          );
        }
        yPos += 10;
      }

      // Similarity Analysis
      if (data.containsKey('similarityAnalysis') &&
          data['similarityAnalysis'] != null) {
        drawWrappedText(
          'Similarity Analysis',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
        );

        drawWrappedText(
          data['similarityAnalysis'],
          PdfStandardFont(PdfFontFamily.helvetica, 10),
        );
        yPos += 10;
      }

      // Recommendations
      if (data.containsKey('recommendations') &&
          data['recommendations'] != null) {
        drawWrappedText(
          'Recommendations',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
        );

        drawWrappedText(
          data['recommendations'],
          PdfStandardFont(PdfFontFamily.helvetica, 10),
        );
        yPos += 10;
      }

      // Suggestions
      final suggestions =
          (data['suggestions'] as List<dynamic>?)?.cast<String>() ?? [];
      if (suggestions.isNotEmpty) {
        drawWrappedText(
          'AI Suggestions',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
        );

        for (var suggestion in suggestions) {
          drawWrappedText(
            '• $suggestion',
            PdfStandardFont(PdfFontFamily.helvetica, 10),
            indent: 10,
          );
        }
      }

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'proposal_analysis_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Open PDF
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
      }
    } catch (e) {
      print('PDF Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final historyAsync = currentUser != null
        ? ref.watch(proposalHistoryStreamProvider(currentUser.uid))
        : const AsyncValue.data(<ProposalHistory>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Research Assistant'),
        actions: [
          // History Drawer Button
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: _buildHistoryDrawer(historyAsync),
      body: Row(
        children: [
          // Input Panel (LEFT)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Verify New Proposal',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter a topic manually or upload a proposal to check for duplicates.',
                    ),
                    const SizedBox(height: 24),

                    // Upload Section
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 32),
                            const SizedBox(height: 8),
                            const Text('Auto-fill from Proposal Document'),
                            if (_selectedFileName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Selected: $_selectedFileName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _isAnalyzing
                                  ? null
                                  : _pickAndUploadDocument,
                              child: _isAnalyzing
                                  ? const Text('Analyzing...')
                                  : const Text('Upload PDF/Doc'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Topic / Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _objectivesController,
                      decoration: const InputDecoration(
                        labelText: 'Objectives / Abstract',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isChecking ? null : _checkProposal,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology),
                      label: const Text('Analyze & Check Duplicates'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Results Panel (RIGHT) - SCROLLABLE
          Expanded(
            flex: 1,
            child: _analysisResult == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_mosaic,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI Analysis Results will appear here',
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildAnalysisView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer(AsyncValue<List<ProposalHistory>> historyAsync) {
    return Drawer(
      width: 350,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Proposal History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No history yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final matchingPct =
                        item.analysis['matchingPercentage'] ?? 0;
                    final dateFormat = DateFormat('MMM dd, HH:mm');

                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () {
                          _loadFromHistory(item);
                          Navigator.of(context).pop(); // Close drawer
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: matchingPct > 70
                                          ? Colors.red
                                          : (matchingPct > 40
                                                ? Colors.orange
                                                : Colors.green),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$matchingPct%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    dateFormat.format(item.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading history',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    final data = _analysisResult!;
    final isDuplicate = data['isDuplicate'] == true;
    final matchingPct = data['matchingPercentage'] ?? 0;
    final matchedProjects =
        (data['matchedProjects'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final similarityText = data['similarityAnalysis'] ?? 'No analysis text.';
    final recommendationsText = data['recommendations'] ?? '';
    final suggestions =
        (data['suggestions'] as List<dynamic>?)?.cast<String>() ?? [];
    final alternativeTitles =
        (data['alternativeTitles'] as List<dynamic>?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      // SCROLLABLE
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export Button
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isExporting ? null : _exportToPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: const Text('Export to PDF'),
            ),
          ),
          const SizedBox(height: 16),

          // Status Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDuplicate
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDuplicate ? Colors.red : Colors.green,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isDuplicate
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                      color: isDuplicate ? Colors.red : Colors.green,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDuplicate
                                ? 'Duplicate / High Similarity Detected'
                                : 'Topic Appears Original',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: isDuplicate
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (isDuplicate)
                            const Text(
                              'Significantly overlaps with existing projects.',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Overall Matching: ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$matchingPct%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: matchingPct > 70
                                ? Colors.red
                                : (matchingPct > 40
                                      ? Colors.orange
                                      : Colors.green),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Matched Projects
          if (matchedProjects.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'Matched Projects (${matchedProjects.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...matchedProjects.map((project) {
              final similarity = project['similarity'] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: similarity > 70
                        ? Colors.red
                        : (similarity > 40 ? Colors.orange : Colors.blue),
                    child: Text(
                      '$similarity%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    project['title'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Student: ${project['studentName']} | ${project['department']} | Year: ${project['year']}',
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 32),
          Text(
            'Similarity Analysis',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(similarityText, style: Theme.of(context).textTheme.bodyLarge),

          if (recommendationsText.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              recommendationsText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],

          const SizedBox(height: 32),
          Text(
            'AI Suggestions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ...suggestions.map(
            (s) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(s),
              ),
            ),
          ),
          if (alternativeTitles.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'Alternative Project Titles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...alternativeTitles.map(
              (title) => Card(
                color: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      _titleController.text = title;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title copied to input')),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
