/// Hive TypeAdapters for book-related data models
///
/// Book, BookSource, UserBook, BookStatus, BookMedium
library;

import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

// ════════════════════════════════════════════
// BookSource Adapter (typeId: 10)
// ════════════════════════════════════════════

class BookSourceAdapter extends TypeAdapter<BookSource> {
  @override
  final int typeId = 10;

  @override
  BookSource read(BinaryReader reader) {
    final ordinal = reader.readByte();
    if (ordinal >= BookSource.values.length) {
      return BookSource.manual;
    }
    return BookSource.values[ordinal];
  }

  @override
  void write(BinaryWriter writer, BookSource obj) {
    writer.writeByte(obj.index);
  }
}

// ════════════════════════════════════════════
// Book Adapter (typeId: 11)
// ════════════════════════════════════════════

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 11;

  @override
  Book read(BinaryReader reader) {
    return Book(
      id: reader.read(),
      isbn13: reader.read(),
      isbn10: reader.read(),
      title: reader.read(),
      authors: (reader.read() as List?)?.cast<String>() ?? [],
      publisher: reader.read(),
      publishedDate: reader.read(),
      description: reader.read(),
      pageCount: reader.read(),
      coverImageUrl: reader.read(),
      source: reader.read(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer.write(obj.id);
    writer.write(obj.isbn13);
    writer.write(obj.isbn10);
    writer.write(obj.title);
    writer.write(obj.authors);
    writer.write(obj.publisher);
    writer.write(obj.publishedDate);
    writer.write(obj.description);
    writer.write(obj.pageCount);
    writer.write(obj.coverImageUrl);
    writer.write(obj.source);
    writer.write(obj.createdAt);
  }
}

// ════════════════════════════════════════════
// BookStatus Adapter (typeId: 12)
// ════════════════════════════════════════════

class BookStatusAdapter extends TypeAdapter<BookStatus> {
  @override
  final int typeId = 12;

  @override
  BookStatus read(BinaryReader reader) {
    final ordinal = reader.readByte();
    if (ordinal >= BookStatus.values.length) {
      return BookStatus.tsundoku;
    }
    return BookStatus.values[ordinal];
  }

  @override
  void write(BinaryWriter writer, BookStatus obj) {
    writer.writeByte(obj.index);
  }
}

// ════════════════════════════════════════════
// BookMedium Adapter (typeId: 13)
// ════════════════════════════════════════════

class BookMediumAdapter extends TypeAdapter<BookMedium> {
  @override
  final int typeId = 13;

  @override
  BookMedium read(BinaryReader reader) {
    final ordinal = reader.readByte();
    if (ordinal >= BookMedium.values.length) {
      return BookMedium.physical;
    }
    return BookMedium.values[ordinal];
  }

  @override
  void write(BinaryWriter writer, BookMedium obj) {
    writer.writeByte(obj.index);
  }
}

// ════════════════════════════════════════════
// UserBook Adapter (typeId: 14)
// ════════════════════════════════════════════

class UserBookAdapter extends TypeAdapter<UserBook> {
  @override
  final int typeId = 14;

  @override
  UserBook read(BinaryReader reader) {
    return UserBook(
      id: reader.read(),
      userId: reader.read(),
      bookId: reader.read(),
      book: reader.read(),
      status: reader.read(),
      medium: reader.read(),
      currentPage: reader.read(),
      totalReadingMinutes: reader.read(),
      rating: reader.read(),
      startedAt: reader.read(),
      completedAt: reader.read(),
      notes: reader.read(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, UserBook obj) {
    writer.write(obj.id);
    writer.write(obj.userId);
    writer.write(obj.bookId);
    writer.write(obj.book);
    writer.write(obj.status);
    writer.write(obj.medium);
    writer.write(obj.currentPage);
    writer.write(obj.totalReadingMinutes);
    writer.write(obj.rating);
    writer.write(obj.startedAt);
    writer.write(obj.completedAt);
    writer.write(obj.notes);
    writer.write(obj.createdAt);
  }
}
