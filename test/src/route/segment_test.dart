import 'package:firecrest/src/route/segment.dart';
import 'package:test/test.dart';

void main() {
  group('overlapsWith', () {
    test('self_doOverlap', () {
      for (var type in SegmentType.values) {
        var segment = Segment('segment', type);
        expect(segment.overlapsWith(segment), isTrue);
      }
    });

    test('normalSegmentsWithSameNames_doOverlap', () {
      var segment1 = Segment('segment', SegmentType.normal);
      var segment2 = Segment('segment', SegmentType.normal);

      expect(segment1.overlapsWith(segment2), isTrue);
    });

    test('normalSegmentsWithDifferentNames_noOverlap', () {
      var segment1 = Segment('segment1', SegmentType.normal);
      var segment2 = Segment('segment2', SegmentType.normal);

      expect(segment1.overlapsWith(segment2), isFalse);
    });

    test('normalSegmentAndWildSegment_noOverlap', () {
      var segment1 = Segment('segment', SegmentType.normal);
      var segment2 = Segment('segment', SegmentType.basicWild);
      var segment3 = Segment('segment', SegmentType.superWild);

      expect(segment1.overlapsWith(segment2), isFalse);
      expect(segment1.overlapsWith(segment3), isFalse);
    });

    test('wildSegments_doOverlap', () {
      var segment1 = Segment('segment1', SegmentType.basicWild);
      var segment2 = Segment('segment2', SegmentType.basicWild);
      var segment3 = Segment('segment3', SegmentType.superWild);

      expect(segment1.overlapsWith(segment2), isTrue);
      expect(segment1.overlapsWith(segment3), isTrue);
    });
  });
}
