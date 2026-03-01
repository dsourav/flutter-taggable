import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'utils/tag_style.dart';

/// A utility function that converts a tag text into a list of inline spans.
///
/// You can use this to convert a string containing tags (in the backend format)
/// into a list of inline spans, where each tag is represented by a custom
/// widget.
///
/// Typically, the [tagStyles] list is the same as the one used in the creation
/// of the tag text to parse the tags. The [backendToTaggable] function is used
/// to convert the backend string into a taggable object and may be asynchronous.
///
/// Usage:
/// ```dart
/// return convertTagTextToInlineSpans<Taggable>(
///   backendFormat,
///   tagStyles: _controller.tagStyles,
///   backendToTaggable: backendToTaggable,
///   taggableToInlineSpan: (taggable, tagStyle) {
///     return TextSpan(
///       text: '${tagStyle.prefix}${taggable.name}',
///       style: tagStyle.textStyle,
///       recognizer: TapGestureRecognizer()
///         ..onTap = () => ScaffoldMessenger.of(context).showSnackBar(
///               SnackBar(
///                 content: Text(
///                   'Tapped ${taggable.name} with id ${taggable.id}',
///                 ),
///                 duration: const Duration(seconds: 2),
///               ),
///             ),
///     );
///   },
/// );
/// ```
List<InlineSpan> convertTagTextToInlineSpans<T>(
  String text, {
  required List<TagStyle> tagStyles,
  required T? Function(String prefix, String backendString) backendToTaggable,
  required InlineSpan Function(T taggable, TagStyle tagStyle)
      taggableToInlineSpan,
  InlineSpan Function(String matchedText, TagStyle tagStyle)?
      nonTaggableToInlineSpan,
  TextStyle? linkStyle,
  void Function(String url)? onLinkTap,
}) {
  final pattern = tagStyles
      .map((style) => '${RegExp.escape(style.prefix)}(${style.regExp})')
      .join('|');
  final spans = <InlineSpan>[];
  int position = 0;

  List<InlineSpan> textWithLinks(String plainText, {TextStyle? baseStyle}) {
    final urlRegex = RegExp(r'((https?:\/\/|www\.)\S+)');
    final parts = <InlineSpan>[];
    int last = 0;
    for (final m in urlRegex.allMatches(plainText)) {
      if (m.start > last) {
        parts.add(TextSpan(
            text: plainText.substring(last, m.start), style: baseStyle));
      }
      final urlText = m.group(0)!;
      final effectiveLinkStyle =
          (linkStyle ?? const TextStyle(color: Colors.blue))
              .merge(const TextStyle(decoration: TextDecoration.underline));
      parts.add(TextSpan(
        text: urlText,
        style: effectiveLinkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => onLinkTap?.call(urlText),
      ));
      last = m.end;
    }
    if (last < plainText.length) {
      parts.add(TextSpan(text: plainText.substring(last), style: baseStyle));
    }
    return parts;
  }

  for (final match in RegExp(pattern).allMatches(text)) {
    final textBeforeTag = text.substring(position, match.start);
    if (textBeforeTag.isNotEmpty) spans.addAll(textWithLinks(textBeforeTag));
    position = match.end;

    final tagStyle = tagStyles.firstWhere(
      (style) => match.group(0)!.startsWith(style.prefix),
    );

    if (tagStyle.isTaggable) {
      final taggable = backendToTaggable(
        tagStyle.prefix,
        match.group(0)!.substring(tagStyle.prefix.length),
      );

      if (taggable != null) {
        spans.add(taggableToInlineSpan(taggable, tagStyle));
      } else {
        spans.add(TextSpan(text: match.group(0)));
      }
    } else {
      if (nonTaggableToInlineSpan != null) {
        spans.add(nonTaggableToInlineSpan(match.group(0)!, tagStyle));
      } else {
        spans.addAll(textWithLinks(match.group(0)!, baseStyle: tagStyle.style));
      }
    }
  }

  final tail = text.substring(position);
  if (tail.isNotEmpty) spans.addAll(textWithLinks(tail));
  return spans;
}
