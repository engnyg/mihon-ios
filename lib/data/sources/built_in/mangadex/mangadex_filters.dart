import '../../base/filter.dart';

class MangaDexFilters {
  MangaDexFilters._();

  static FilterList get filterList => FilterList([
        SelectFilter(
          name: 'Content Rating',
          values: ['Safe', 'Suggestive', 'Erotica'],
        ),
        SelectFilter(
          name: 'Status',
          values: ['Any', 'Ongoing', 'Completed', 'Hiatus', 'Cancelled'],
        ),
        SelectFilter(
          name: 'Sort By',
          values: [
            'Best Match',
            'Followed Count',
            'Relevance',
            'Latest Upload',
            'Oldest Upload',
            'Title Ascending',
            'Title Descending',
            'Rating',
            'Fewest Chapters',
            'Recently Added',
          ],
        ),
      ]);
}
