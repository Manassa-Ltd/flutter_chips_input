import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'suggestions_box_controller.dart';
import 'text_cursor.dart';

typedef ChipsInputSuggestions<T> = FutureOr<List<T>> Function(String query);
typedef ChipSelected<T> = void Function(T data, bool selected);
typedef ChipsBuilder<T> = Widget Function(
    BuildContext context,
    ChipsInputState<T> state,
    int index,
    T data,
    );
typedef SuggestionBuilder<T> = Widget Function(
    BuildContext context,
    ChipsInputState<T> state,
    List<T> data,
    );
typedef OnSubmitCallback<T> = T? Function(String txt);
typedef OnChipDeleted<T> = void Function(List<T> chips, int index);

const kObjectReplacementChar = 0xFFFD;

extension on TextEditingValue {
  String get normalCharactersText => String.fromCharCodes(
    text.codeUnits.where((ch) => ch != kObjectReplacementChar),
  );

  List<int> get replacementCharacters => text.codeUnits.where((ch) => ch == kObjectReplacementChar).toList(growable: false);

  int get replacementCharactersCount => replacementCharacters.length;
}

class ChipsInput<T> extends StatefulWidget {
  const ChipsInput({
    super.key,
    this.initialValue = const [],
    this.decoration = const InputDecoration(),
    this.enabled = true,
    required this.chipBuilder,
    this.findSuggestions,
    this.onSubmit,
    this.submitKeys = const [LogicalKeyboardKey.tab],
    this.existingValues = const [],
    required this.onChanged,
    this.suggestionBuilder,
    this.suggestionsBuilder,
    this.onChipDeleted,
    this.maxChips,
    this.textStyle,
    this.suggestionsBoxMaxHeight,
    this.inputType = TextInputType.text,
    this.textOverflow = TextOverflow.clip,
    this.obscureText = false,
    this.autocorrect = true,
    this.actionLabel,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.allowChipEditing = false,
    this.focusNode,
    this.initialSuggestions,
  }) : assert(maxChips == null || initialValue.length <= maxChips);

  final InputDecoration decoration;
  final TextStyle? textStyle;
  final bool enabled;
  final ChipsInputSuggestions<T>? findSuggestions;
  final List<String> existingValues;
  final OnSubmitCallback<T>? onSubmit;
  final List<KeyboardKey> submitKeys;
  final ValueChanged<List<T>> onChanged;
  final ChipsBuilder<T> chipBuilder;
  final ChipsBuilder<T>? suggestionBuilder;
  final SuggestionBuilder<T>? suggestionsBuilder;
  final OnChipDeleted<T>? onChipDeleted;
  final List<T> initialValue;
  final int? maxChips;
  final double? suggestionsBoxMaxHeight;
  final TextInputType inputType;
  final TextOverflow textOverflow;
  final bool obscureText;
  final bool autocorrect;
  final String? actionLabel;
  final TextInputAction inputAction;
  final Brightness keyboardAppearance;
  final bool autofocus;
  final bool allowChipEditing;
  final FocusNode? focusNode;
  final List<T>? initialSuggestions;

  // final Color cursorColor;

  final TextCapitalization textCapitalization;

  @override
  ChipsInputState<T> createState() => ChipsInputState<T>();
}

class ChipsInputState<T> extends State<ChipsInput<T>> implements TextInputClient {
  List<T> _chips = <T>[];
  List<T?>? _suggestions;
  final StreamController<List<T?>?> _suggestionsStreamController = StreamController<List<T>?>.broadcast();
  int _searchId = 0;
  TextEditingValue _value = const TextEditingValue();
  TextInputConnection? _textInputConnection;
  late SuggestionsBoxController _suggestionsBoxController;
  final _layerLink = LayerLink();
  final Map<T?, String> _enteredTexts = <T, String>{};

  int? _viewId;

  TextInputConfiguration get textInputConfiguration {
    final viewId = View.of(context).viewId;
    _viewId = viewId;

    return TextInputConfiguration(
      viewId: viewId,
      inputType: widget.inputType,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      actionLabel: widget.actionLabel,
      inputAction: widget.inputAction,
      keyboardAppearance: widget.keyboardAppearance,
      textCapitalization: widget.textCapitalization,
    );
  }

  bool get _hasInputConnection => _textInputConnection != null && _textInputConnection!.attached;

  bool get _hasReachedMaxChips => widget.maxChips != null && _chips.length >= widget.maxChips!;

  FocusNode? _focusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_focusNode ??= FocusNode());
  late FocusAttachment _nodeAttachment;

  RenderBox? get renderBox => context.findRenderObject() as RenderBox?;

  bool get _canRequestFocus => widget.enabled;

  @override
  void initState() {
    super.initState();
    _chips.addAll(widget.initialValue);
    _suggestions = widget.initialSuggestions?.where((r) => !_chips.contains(r)).toList(growable: false);
    _suggestionsBoxController = SuggestionsBoxController(context);

    _effectiveFocusNode.addListener(_handleFocusChanged);
    _nodeAttachment = _effectiveFocusNode.attach(context);
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initOverlayEntry();
      if (mounted && widget.autofocus) {
        FocusScope.of(context).autofocus(_effectiveFocusNode);
      }
    });

    _effectiveFocusNode.addListener(() {
      if (_effectiveFocusNode.hasFocus) _onSearchChanged(_value.text);
    });
  }

  @override
  void dispose() {
    _closeInputConnectionIfNeeded();
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _focusNode?.dispose();
    _suggestionsStreamController.close();
    _suggestionsBoxController.close();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_effectiveFocusNode.hasFocus) {
      _updateViewIdIfNeeded();
      _openInputConnection();
      _suggestionsBoxController.open();
    } else {
      _closeInputConnectionIfNeeded();
      _suggestionsBoxController.close();
    }
    if (mounted) {
      setState(() {
        /*rebuild so that _TextCursor is hidden.*/
      });
    }
  }

  void requestKeyboard() {
    if (_effectiveFocusNode.hasFocus) {
      _openInputConnection();
    } else {
      FocusScope.of(context).requestFocus(_effectiveFocusNode);
    }
  }

  Widget _defaultSuggestionsBuilder(BuildContext ctx, List<T> suggestions) {
    return Material(
      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: ScrollController(),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    if (widget.suggestionBuilder == null) ...suggestions.map((suggestion) => _defaultSuggestionBuilder(suggestion)),
                    if (widget.suggestionBuilder != null)
                      ...suggestions.map(
                            (suggestion) {
                          final index = suggestions.indexOf(suggestion);
                          return widget.suggestionBuilder!.call(ctx, this, index, suggestion);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultSuggestionBuilder(T suggestion) {
    return InputChip(
      label: Text('$suggestion'),
      onPressed: () => selectSuggestion(suggestion),
    );
  }

  void _initOverlayEntry() {
    // Skip if suggestions are null
    if (widget.findSuggestions == null) return;

    _suggestionsBoxController.overlayEntry = OverlayEntry(
      builder: (context) {
        final size = renderBox!.size;
        final renderBoxOffset = renderBox!.localToGlobal(Offset.zero);
        final mq = MediaQuery.of(context);
        final bottomAvailableSpace = mq.size.height - mq.viewInsets.bottom - renderBoxOffset.dy - size.height;
        var suggestionBoxHeight = max(renderBoxOffset.dy, bottomAvailableSpace);

        if (widget.suggestionsBoxMaxHeight != null) {
          suggestionBoxHeight = min(suggestionBoxHeight, widget.suggestionsBoxMaxHeight!);
        }

        final showTop = renderBoxOffset.dy > bottomAvailableSpace;

        return StreamBuilder<List<T?>?>(
          stream: _suggestionsStreamController.stream,
          initialData: _suggestions,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final suggestionsListView = ConstrainedBox(
                constraints: BoxConstraints(maxHeight: suggestionBoxHeight),
                child: widget.suggestionsBuilder != null ? widget.suggestionsBuilder!(context, this, _suggestions!.cast()) : _defaultSuggestionsBuilder(context, _suggestions!.cast()),
              );

              return Positioned(
                width: size.width,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: showTop ? Offset(0, -size.height) : Offset.zero,
                  child: Container(
                    color: Colors.white,
                    child: !showTop
                        ? suggestionsListView
                        : FractionalTranslation(
                      translation: const Offset(0, -1),
                      child: suggestionsListView,
                    ),
                  ),
                ),
              );
            }
            return Container(); // Return empty container if no suggestions
          },
        );
      },
    );
  }

  void _onSearchChanged(String value) async {
    // Skip if no suggestions function
    if (widget.findSuggestions == null) return;

    final localId = ++_searchId;
    final results = await widget.findSuggestions!(value);
    if (_searchId == localId && mounted) {
      setState(() {
        _suggestions = results.where((r) => !_chips.contains(r)).toList(growable: false);
      });
    }

    _suggestionsStreamController.add(_suggestions ?? []);

    if (!_suggestionsBoxController.isOpened && !_hasReachedMaxChips) {
      _suggestionsBoxController.open();
    }
  }

  void selectSuggestion(T data) {
    if (!_hasReachedMaxChips) {
      setState(() {
        _chips.add(data);
        _updateTextInputState(replaceText: true);
        _suggestions = null;
      });

      _suggestionsStreamController.add(_suggestions);
      _suggestionsBoxController.close(); // Close suggestions box

      widget.onChanged(_chips.toList(growable: false));
    }
  }

  void deleteChip(int index) {
    if (widget.enabled) {
      final data = _chips[index];
      setState(() => _chips.removeAt(index));
      if (_enteredTexts.containsKey(data)) _enteredTexts.remove(data);
      _updateTextInputState();
      widget.onChanged(_chips.toList(growable: false));
    }
  }

  void _openInputConnection() {
    if (!_hasInputConnection) {
      _textInputConnection = TextInput.attach(this, textInputConfiguration);
      _textInputConnection!.show();
      _updateTextInputState();
    } else {
      _textInputConnection?.show();
    }

    // _scrollToVisible();
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    //print("updateEditingValue FIRED with ${value.text}");
    // _receivedRemoteTextEditingValue = value;
    final oldTextEditingValue = _value;
    if (value.text != oldTextEditingValue.text) {
      setState(() => _value = value);
      if (value.replacementCharactersCount < oldTextEditingValue.replacementCharactersCount) {
        final removedChip = _chips.last;
        setState(() => _chips = List.of(_chips.take(value.replacementCharactersCount)));
        widget.onChanged(_chips.toList(growable: false));
        String? putText = '';
        if (widget.allowChipEditing && _enteredTexts.containsKey(removedChip)) {
          putText = _enteredTexts[removedChip]!;
          _enteredTexts.remove(removedChip);
        }
        _updateTextInputState(putText: putText);
      } else {
        _updateTextInputState();
      }
      _onSearchChanged(_value.normalCharactersText);
    }
  }

  void _updateTextInputState({bool replaceText = false, String putText = ''}) {
    if (replaceText || putText.isNotEmpty) {
      final updatedText = "${replaceText ? '' : _value.normalCharactersText}$putText";
      setState(
            () => _value = _value.copyWith(
          text: updatedText,
          selection: TextSelection.collapsed(offset: updatedText.length),
          // composing: TextRange(start: 0, end: updatedText.length),
          composing: TextRange.empty,
        ),
      );
    }
    if (_hasInputConnection) {
      _textInputConnection!.setEditingState(_value);
    }
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.go:
      case TextInputAction.done:
      case TextInputAction.send:
      case TextInputAction.next:
      case TextInputAction.search:
      case TextInputAction.newline:
      case TextInputAction.continueAction:
        _performAction();
        break;
      default:
        break;
    }
  }

  void _performAction() {
    final value = widget.onSubmit?.call(_value.text);
    if (value != null) selectSuggestion(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
    _updateViewIdIfNeeded();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    //TODO
  }

  @override
  void didUpdateWidget(covariant ChipsInput<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
    _updateViewIdIfNeeded();
  }

  void _updateViewIdIfNeeded() {
    if (!_hasInputConnection) {
      _viewId = View.of(context).viewId;
      return;
    }

    final newViewId = View.of(context).viewId;
    if (newViewId != _viewId) {
      _viewId = newViewId;
      _textInputConnection?.updateConfig(textInputConfiguration);
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print(point);
  }

  @override
  void connectionClosed() {
    //print('TextInputClient.connectionClosed()');
  }

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  Widget build(BuildContext context) {
    _nodeAttachment.reparent();
    final chipsChildren = _chips.map<Widget>(
          (chip) {
        final index = _chips.indexOf(chip);
        return widget.chipBuilder(context, this, index, chip);
      },
    ).toList();

    final theme = Theme.of(context);

    chipsChildren.add(
      SizedBox(
        height: 30.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Flexible(
              flex: 1,
              child: Text(
                _value.normalCharactersText,
                maxLines: 1,
                overflow: widget.textOverflow,
                style: widget.textStyle?.copyWith(fontSize: 13.0) ?? theme.textTheme.titleMedium?.copyWith(height: 1.2),
              ),
            ),
            Flexible(
              flex: 0,
              child: TextCursor(resumed: _effectiveFocusNode.hasFocus),
            ),
          ],
        ),
      ),
    );

    return KeyboardListener(
      focusNode: _effectiveFocusNode,
      onKeyEvent: (event) {
        final str = _value.text;

        // Handle KeyDownEvent to avoid duplicate events
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (str.isNotEmpty) {
              final sd = str.substring(0, str.length - 1);

              /// Make sure to also update cursor position using
              /// the TextSelection.collapsed.
              updateEditingValue(
                TextEditingValue(
                  text: sd,
                  selection: TextSelection.collapsed(
                    offset: sd.length,
                  ),
                ),
              );
            } else if (_chips.isNotEmpty) {
              // Remove the last chip when backspace is pressed with an empty input
              deleteChip(_chips.length - 1);
            }
          }

          for(final key in widget.submitKeys) {
            if(event.physicalKey == key || event.logicalKey == key) {
              _performAction();
              break;
            }
          }
        }
      },
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (SizeChangedLayoutNotification val) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            _suggestionsBoxController.overlayEntry?.markNeedsBuild();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: Column(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => requestKeyboard(),
                child: InputDecorator(
                  decoration: widget.decoration.copyWith(
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10), // Reduce vertical padding
                  ),
                  isFocused: _effectiveFocusNode.hasFocus,
                  isEmpty: _value.text.isEmpty && _chips.isEmpty,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: chipsChildren,
                  ),
                ),
              ),
              CompositedTransformTarget(
                link: _layerLink,
                child: Container(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
  }

  @override
  void showToolbar() {
    // TODO: implement showToolbar
  }

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    // TODO: implement didChangeInputControl
  }

  @override
  void performSelector(String selectorName) {
    // TODO: implement performSelector
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    // TODO: implement insertContent
  }
}
