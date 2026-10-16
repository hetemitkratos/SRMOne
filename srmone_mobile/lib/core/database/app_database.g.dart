// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StudentProfilesTable extends StudentProfiles
    with TableInfo<$StudentProfilesTable, StudentProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _regNumberMeta =
      const VerificationMeta('regNumber');
  @override
  late final GeneratedColumn<String> regNumber = GeneratedColumn<String>(
      'reg_number', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _cgpaMeta = const VerificationMeta('cgpa');
  @override
  late final GeneratedColumn<double> cgpa = GeneratedColumn<double>(
      'cgpa', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
      'branch', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sectionMeta =
      const VerificationMeta('section');
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
      'section', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _semesterMeta =
      const VerificationMeta('semester');
  @override
  late final GeneratedColumn<String> semester = GeneratedColumn<String>(
      'semester', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _batchMeta = const VerificationMeta('batch');
  @override
  late final GeneratedColumn<String> batch = GeneratedColumn<String>(
      'batch', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _parentEmailMeta =
      const VerificationMeta('parentEmail');
  @override
  late final GeneratedColumn<String> parentEmail = GeneratedColumn<String>(
      'parent_email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _parentPhoneMeta =
      const VerificationMeta('parentPhone');
  @override
  late final GeneratedColumn<String> parentPhone = GeneratedColumn<String>(
      'parent_phone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _mentorMeta = const VerificationMeta('mentor');
  @override
  late final GeneratedColumn<String> mentor = GeneratedColumn<String>(
      'mentor', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _programMeta =
      const VerificationMeta('program');
  @override
  late final GeneratedColumn<String> program = GeneratedColumn<String>(
      'program', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _campusMeta = const VerificationMeta('campus');
  @override
  late final GeneratedColumn<String> campus = GeneratedColumn<String>(
      'campus', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _rawDataJsonMeta =
      const VerificationMeta('rawDataJson');
  @override
  late final GeneratedColumn<String> rawDataJson = GeneratedColumn<String>(
      'raw_data_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        academiaEmail,
        name,
        regNumber,
        photoUrl,
        cgpa,
        branch,
        section,
        semester,
        batch,
        phone,
        email,
        parentEmail,
        parentPhone,
        mentor,
        program,
        campus,
        rawDataJson,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'student_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<StudentProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('reg_number')) {
      context.handle(_regNumberMeta,
          regNumber.isAcceptableOrUnknown(data['reg_number']!, _regNumberMeta));
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('cgpa')) {
      context.handle(
          _cgpaMeta, cgpa.isAcceptableOrUnknown(data['cgpa']!, _cgpaMeta));
    }
    if (data.containsKey('branch')) {
      context.handle(_branchMeta,
          branch.isAcceptableOrUnknown(data['branch']!, _branchMeta));
    }
    if (data.containsKey('section')) {
      context.handle(_sectionMeta,
          section.isAcceptableOrUnknown(data['section']!, _sectionMeta));
    }
    if (data.containsKey('semester')) {
      context.handle(_semesterMeta,
          semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta));
    }
    if (data.containsKey('batch')) {
      context.handle(
          _batchMeta, batch.isAcceptableOrUnknown(data['batch']!, _batchMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('parent_email')) {
      context.handle(
          _parentEmailMeta,
          parentEmail.isAcceptableOrUnknown(
              data['parent_email']!, _parentEmailMeta));
    }
    if (data.containsKey('parent_phone')) {
      context.handle(
          _parentPhoneMeta,
          parentPhone.isAcceptableOrUnknown(
              data['parent_phone']!, _parentPhoneMeta));
    }
    if (data.containsKey('mentor')) {
      context.handle(_mentorMeta,
          mentor.isAcceptableOrUnknown(data['mentor']!, _mentorMeta));
    }
    if (data.containsKey('program')) {
      context.handle(_programMeta,
          program.isAcceptableOrUnknown(data['program']!, _programMeta));
    }
    if (data.containsKey('campus')) {
      context.handle(_campusMeta,
          campus.isAcceptableOrUnknown(data['campus']!, _campusMeta));
    }
    if (data.containsKey('raw_data_json')) {
      context.handle(
          _rawDataJsonMeta,
          rawDataJson.isAcceptableOrUnknown(
              data['raw_data_json']!, _rawDataJsonMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail};
  @override
  StudentProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentProfile(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      regNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reg_number'])!,
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url'])!,
      cgpa: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cgpa'])!,
      branch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch'])!,
      section: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}section'])!,
      semester: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester'])!,
      batch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      parentEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_email'])!,
      parentPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_phone'])!,
      mentor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mentor'])!,
      program: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program'])!,
      campus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}campus'])!,
      rawDataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_data_json'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $StudentProfilesTable createAlias(String alias) {
    return $StudentProfilesTable(attachedDatabase, alias);
  }
}

class StudentProfile extends DataClass implements Insertable<StudentProfile> {
  final String academiaEmail;
  final String name;
  final String regNumber;
  final String photoUrl;
  final double cgpa;
  final String branch;
  final String section;
  final String semester;
  final String batch;
  final String phone;
  final String email;
  final String parentEmail;
  final String parentPhone;
  final String mentor;
  final String program;
  final String campus;
  final String rawDataJson;
  final int cachedAt;
  const StudentProfile(
      {required this.academiaEmail,
      required this.name,
      required this.regNumber,
      required this.photoUrl,
      required this.cgpa,
      required this.branch,
      required this.section,
      required this.semester,
      required this.batch,
      required this.phone,
      required this.email,
      required this.parentEmail,
      required this.parentPhone,
      required this.mentor,
      required this.program,
      required this.campus,
      required this.rawDataJson,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['name'] = Variable<String>(name);
    map['reg_number'] = Variable<String>(regNumber);
    map['photo_url'] = Variable<String>(photoUrl);
    map['cgpa'] = Variable<double>(cgpa);
    map['branch'] = Variable<String>(branch);
    map['section'] = Variable<String>(section);
    map['semester'] = Variable<String>(semester);
    map['batch'] = Variable<String>(batch);
    map['phone'] = Variable<String>(phone);
    map['email'] = Variable<String>(email);
    map['parent_email'] = Variable<String>(parentEmail);
    map['parent_phone'] = Variable<String>(parentPhone);
    map['mentor'] = Variable<String>(mentor);
    map['program'] = Variable<String>(program);
    map['campus'] = Variable<String>(campus);
    map['raw_data_json'] = Variable<String>(rawDataJson);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  StudentProfilesCompanion toCompanion(bool nullToAbsent) {
    return StudentProfilesCompanion(
      academiaEmail: Value(academiaEmail),
      name: Value(name),
      regNumber: Value(regNumber),
      photoUrl: Value(photoUrl),
      cgpa: Value(cgpa),
      branch: Value(branch),
      section: Value(section),
      semester: Value(semester),
      batch: Value(batch),
      phone: Value(phone),
      email: Value(email),
      parentEmail: Value(parentEmail),
      parentPhone: Value(parentPhone),
      mentor: Value(mentor),
      program: Value(program),
      campus: Value(campus),
      rawDataJson: Value(rawDataJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentProfile(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      name: serializer.fromJson<String>(json['name']),
      regNumber: serializer.fromJson<String>(json['regNumber']),
      photoUrl: serializer.fromJson<String>(json['photoUrl']),
      cgpa: serializer.fromJson<double>(json['cgpa']),
      branch: serializer.fromJson<String>(json['branch']),
      section: serializer.fromJson<String>(json['section']),
      semester: serializer.fromJson<String>(json['semester']),
      batch: serializer.fromJson<String>(json['batch']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String>(json['email']),
      parentEmail: serializer.fromJson<String>(json['parentEmail']),
      parentPhone: serializer.fromJson<String>(json['parentPhone']),
      mentor: serializer.fromJson<String>(json['mentor']),
      program: serializer.fromJson<String>(json['program']),
      campus: serializer.fromJson<String>(json['campus']),
      rawDataJson: serializer.fromJson<String>(json['rawDataJson']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'name': serializer.toJson<String>(name),
      'regNumber': serializer.toJson<String>(regNumber),
      'photoUrl': serializer.toJson<String>(photoUrl),
      'cgpa': serializer.toJson<double>(cgpa),
      'branch': serializer.toJson<String>(branch),
      'section': serializer.toJson<String>(section),
      'semester': serializer.toJson<String>(semester),
      'batch': serializer.toJson<String>(batch),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String>(email),
      'parentEmail': serializer.toJson<String>(parentEmail),
      'parentPhone': serializer.toJson<String>(parentPhone),
      'mentor': serializer.toJson<String>(mentor),
      'program': serializer.toJson<String>(program),
      'campus': serializer.toJson<String>(campus),
      'rawDataJson': serializer.toJson<String>(rawDataJson),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  StudentProfile copyWith(
          {String? academiaEmail,
          String? name,
          String? regNumber,
          String? photoUrl,
          double? cgpa,
          String? branch,
          String? section,
          String? semester,
          String? batch,
          String? phone,
          String? email,
          String? parentEmail,
          String? parentPhone,
          String? mentor,
          String? program,
          String? campus,
          String? rawDataJson,
          int? cachedAt}) =>
      StudentProfile(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        name: name ?? this.name,
        regNumber: regNumber ?? this.regNumber,
        photoUrl: photoUrl ?? this.photoUrl,
        cgpa: cgpa ?? this.cgpa,
        branch: branch ?? this.branch,
        section: section ?? this.section,
        semester: semester ?? this.semester,
        batch: batch ?? this.batch,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        parentEmail: parentEmail ?? this.parentEmail,
        parentPhone: parentPhone ?? this.parentPhone,
        mentor: mentor ?? this.mentor,
        program: program ?? this.program,
        campus: campus ?? this.campus,
        rawDataJson: rawDataJson ?? this.rawDataJson,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  StudentProfile copyWithCompanion(StudentProfilesCompanion data) {
    return StudentProfile(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      name: data.name.present ? data.name.value : this.name,
      regNumber: data.regNumber.present ? data.regNumber.value : this.regNumber,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      cgpa: data.cgpa.present ? data.cgpa.value : this.cgpa,
      branch: data.branch.present ? data.branch.value : this.branch,
      section: data.section.present ? data.section.value : this.section,
      semester: data.semester.present ? data.semester.value : this.semester,
      batch: data.batch.present ? data.batch.value : this.batch,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      parentEmail:
          data.parentEmail.present ? data.parentEmail.value : this.parentEmail,
      parentPhone:
          data.parentPhone.present ? data.parentPhone.value : this.parentPhone,
      mentor: data.mentor.present ? data.mentor.value : this.mentor,
      program: data.program.present ? data.program.value : this.program,
      campus: data.campus.present ? data.campus.value : this.campus,
      rawDataJson:
          data.rawDataJson.present ? data.rawDataJson.value : this.rawDataJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentProfile(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('name: $name, ')
          ..write('regNumber: $regNumber, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('cgpa: $cgpa, ')
          ..write('branch: $branch, ')
          ..write('section: $section, ')
          ..write('semester: $semester, ')
          ..write('batch: $batch, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('parentEmail: $parentEmail, ')
          ..write('parentPhone: $parentPhone, ')
          ..write('mentor: $mentor, ')
          ..write('program: $program, ')
          ..write('campus: $campus, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      academiaEmail,
      name,
      regNumber,
      photoUrl,
      cgpa,
      branch,
      section,
      semester,
      batch,
      phone,
      email,
      parentEmail,
      parentPhone,
      mentor,
      program,
      campus,
      rawDataJson,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentProfile &&
          other.academiaEmail == this.academiaEmail &&
          other.name == this.name &&
          other.regNumber == this.regNumber &&
          other.photoUrl == this.photoUrl &&
          other.cgpa == this.cgpa &&
          other.branch == this.branch &&
          other.section == this.section &&
          other.semester == this.semester &&
          other.batch == this.batch &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.parentEmail == this.parentEmail &&
          other.parentPhone == this.parentPhone &&
          other.mentor == this.mentor &&
          other.program == this.program &&
          other.campus == this.campus &&
          other.rawDataJson == this.rawDataJson &&
          other.cachedAt == this.cachedAt);
}

class StudentProfilesCompanion extends UpdateCompanion<StudentProfile> {
  final Value<String> academiaEmail;
  final Value<String> name;
  final Value<String> regNumber;
  final Value<String> photoUrl;
  final Value<double> cgpa;
  final Value<String> branch;
  final Value<String> section;
  final Value<String> semester;
  final Value<String> batch;
  final Value<String> phone;
  final Value<String> email;
  final Value<String> parentEmail;
  final Value<String> parentPhone;
  final Value<String> mentor;
  final Value<String> program;
  final Value<String> campus;
  final Value<String> rawDataJson;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const StudentProfilesCompanion({
    this.academiaEmail = const Value.absent(),
    this.name = const Value.absent(),
    this.regNumber = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.cgpa = const Value.absent(),
    this.branch = const Value.absent(),
    this.section = const Value.absent(),
    this.semester = const Value.absent(),
    this.batch = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.parentEmail = const Value.absent(),
    this.parentPhone = const Value.absent(),
    this.mentor = const Value.absent(),
    this.program = const Value.absent(),
    this.campus = const Value.absent(),
    this.rawDataJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentProfilesCompanion.insert({
    required String academiaEmail,
    required String name,
    this.regNumber = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.cgpa = const Value.absent(),
    this.branch = const Value.absent(),
    this.section = const Value.absent(),
    this.semester = const Value.absent(),
    this.batch = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.parentEmail = const Value.absent(),
    this.parentPhone = const Value.absent(),
    this.mentor = const Value.absent(),
    this.program = const Value.absent(),
    this.campus = const Value.absent(),
    this.rawDataJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : academiaEmail = Value(academiaEmail),
        name = Value(name);
  static Insertable<StudentProfile> custom({
    Expression<String>? academiaEmail,
    Expression<String>? name,
    Expression<String>? regNumber,
    Expression<String>? photoUrl,
    Expression<double>? cgpa,
    Expression<String>? branch,
    Expression<String>? section,
    Expression<String>? semester,
    Expression<String>? batch,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? parentEmail,
    Expression<String>? parentPhone,
    Expression<String>? mentor,
    Expression<String>? program,
    Expression<String>? campus,
    Expression<String>? rawDataJson,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (name != null) 'name': name,
      if (regNumber != null) 'reg_number': regNumber,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (cgpa != null) 'cgpa': cgpa,
      if (branch != null) 'branch': branch,
      if (section != null) 'section': section,
      if (semester != null) 'semester': semester,
      if (batch != null) 'batch': batch,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (parentEmail != null) 'parent_email': parentEmail,
      if (parentPhone != null) 'parent_phone': parentPhone,
      if (mentor != null) 'mentor': mentor,
      if (program != null) 'program': program,
      if (campus != null) 'campus': campus,
      if (rawDataJson != null) 'raw_data_json': rawDataJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentProfilesCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? name,
      Value<String>? regNumber,
      Value<String>? photoUrl,
      Value<double>? cgpa,
      Value<String>? branch,
      Value<String>? section,
      Value<String>? semester,
      Value<String>? batch,
      Value<String>? phone,
      Value<String>? email,
      Value<String>? parentEmail,
      Value<String>? parentPhone,
      Value<String>? mentor,
      Value<String>? program,
      Value<String>? campus,
      Value<String>? rawDataJson,
      Value<int>? cachedAt,
      Value<int>? rowid}) {
    return StudentProfilesCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      name: name ?? this.name,
      regNumber: regNumber ?? this.regNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      cgpa: cgpa ?? this.cgpa,
      branch: branch ?? this.branch,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      batch: batch ?? this.batch,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      parentEmail: parentEmail ?? this.parentEmail,
      parentPhone: parentPhone ?? this.parentPhone,
      mentor: mentor ?? this.mentor,
      program: program ?? this.program,
      campus: campus ?? this.campus,
      rawDataJson: rawDataJson ?? this.rawDataJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (regNumber.present) {
      map['reg_number'] = Variable<String>(regNumber.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (cgpa.present) {
      map['cgpa'] = Variable<double>(cgpa.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (semester.present) {
      map['semester'] = Variable<String>(semester.value);
    }
    if (batch.present) {
      map['batch'] = Variable<String>(batch.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (parentEmail.present) {
      map['parent_email'] = Variable<String>(parentEmail.value);
    }
    if (parentPhone.present) {
      map['parent_phone'] = Variable<String>(parentPhone.value);
    }
    if (mentor.present) {
      map['mentor'] = Variable<String>(mentor.value);
    }
    if (program.present) {
      map['program'] = Variable<String>(program.value);
    }
    if (campus.present) {
      map['campus'] = Variable<String>(campus.value);
    }
    if (rawDataJson.present) {
      map['raw_data_json'] = Variable<String>(rawDataJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentProfilesCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('name: $name, ')
          ..write('regNumber: $regNumber, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('cgpa: $cgpa, ')
          ..write('branch: $branch, ')
          ..write('section: $section, ')
          ..write('semester: $semester, ')
          ..write('batch: $batch, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('parentEmail: $parentEmail, ')
          ..write('parentPhone: $parentPhone, ')
          ..write('mentor: $mentor, ')
          ..write('program: $program, ')
          ..write('campus: $campus, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendanceCacheTable extends AttendanceCache
    with TableInfo<$AttendanceCacheTable, AttendanceCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseCodeMeta =
      const VerificationMeta('courseCode');
  @override
  late final GeneratedColumn<String> courseCode = GeneratedColumn<String>(
      'course_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseTitleMeta =
      const VerificationMeta('courseTitle');
  @override
  late final GeneratedColumn<String> courseTitle = GeneratedColumn<String>(
      'course_title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _facultyNameMeta =
      const VerificationMeta('facultyName');
  @override
  late final GeneratedColumn<String> facultyName = GeneratedColumn<String>(
      'faculty_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
      'slot', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _roomNoMeta = const VerificationMeta('roomNo');
  @override
  late final GeneratedColumn<String> roomNo = GeneratedColumn<String>(
      'room_no', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _hoursConductedMeta =
      const VerificationMeta('hoursConducted');
  @override
  late final GeneratedColumn<int> hoursConducted = GeneratedColumn<int>(
      'hours_conducted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _hoursAbsentMeta =
      const VerificationMeta('hoursAbsent');
  @override
  late final GeneratedColumn<int> hoursAbsent = GeneratedColumn<int>(
      'hours_absent', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _attendancePctMeta =
      const VerificationMeta('attendancePct');
  @override
  late final GeneratedColumn<double> attendancePct = GeneratedColumn<double>(
      'attendance_pct', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('academia'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        academiaEmail,
        courseCode,
        courseTitle,
        category,
        facultyName,
        slot,
        roomNo,
        hoursConducted,
        hoursAbsent,
        attendancePct,
        source,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<AttendanceCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('course_code')) {
      context.handle(
          _courseCodeMeta,
          courseCode.isAcceptableOrUnknown(
              data['course_code']!, _courseCodeMeta));
    } else if (isInserting) {
      context.missing(_courseCodeMeta);
    }
    if (data.containsKey('course_title')) {
      context.handle(
          _courseTitleMeta,
          courseTitle.isAcceptableOrUnknown(
              data['course_title']!, _courseTitleMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('faculty_name')) {
      context.handle(
          _facultyNameMeta,
          facultyName.isAcceptableOrUnknown(
              data['faculty_name']!, _facultyNameMeta));
    }
    if (data.containsKey('slot')) {
      context.handle(
          _slotMeta, slot.isAcceptableOrUnknown(data['slot']!, _slotMeta));
    }
    if (data.containsKey('room_no')) {
      context.handle(_roomNoMeta,
          roomNo.isAcceptableOrUnknown(data['room_no']!, _roomNoMeta));
    }
    if (data.containsKey('hours_conducted')) {
      context.handle(
          _hoursConductedMeta,
          hoursConducted.isAcceptableOrUnknown(
              data['hours_conducted']!, _hoursConductedMeta));
    }
    if (data.containsKey('hours_absent')) {
      context.handle(
          _hoursAbsentMeta,
          hoursAbsent.isAcceptableOrUnknown(
              data['hours_absent']!, _hoursAbsentMeta));
    }
    if (data.containsKey('attendance_pct')) {
      context.handle(
          _attendancePctMeta,
          attendancePct.isAcceptableOrUnknown(
              data['attendance_pct']!, _attendancePctMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail, courseCode, category};
  @override
  AttendanceCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceCacheData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      courseCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_code'])!,
      courseTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      facultyName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}faculty_name'])!,
      slot: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot'])!,
      roomNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_no'])!,
      hoursConducted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hours_conducted'])!,
      hoursAbsent: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hours_absent'])!,
      attendancePct: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}attendance_pct'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AttendanceCacheTable createAlias(String alias) {
    return $AttendanceCacheTable(attachedDatabase, alias);
  }
}

class AttendanceCacheData extends DataClass
    implements Insertable<AttendanceCacheData> {
  final String academiaEmail;
  final String courseCode;
  final String courseTitle;
  final String category;
  final String facultyName;
  final String slot;
  final String roomNo;
  final int hoursConducted;
  final int hoursAbsent;
  final double attendancePct;
  final String source;
  final int updatedAt;
  const AttendanceCacheData(
      {required this.academiaEmail,
      required this.courseCode,
      required this.courseTitle,
      required this.category,
      required this.facultyName,
      required this.slot,
      required this.roomNo,
      required this.hoursConducted,
      required this.hoursAbsent,
      required this.attendancePct,
      required this.source,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['course_code'] = Variable<String>(courseCode);
    map['course_title'] = Variable<String>(courseTitle);
    map['category'] = Variable<String>(category);
    map['faculty_name'] = Variable<String>(facultyName);
    map['slot'] = Variable<String>(slot);
    map['room_no'] = Variable<String>(roomNo);
    map['hours_conducted'] = Variable<int>(hoursConducted);
    map['hours_absent'] = Variable<int>(hoursAbsent);
    map['attendance_pct'] = Variable<double>(attendancePct);
    map['source'] = Variable<String>(source);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AttendanceCacheCompanion toCompanion(bool nullToAbsent) {
    return AttendanceCacheCompanion(
      academiaEmail: Value(academiaEmail),
      courseCode: Value(courseCode),
      courseTitle: Value(courseTitle),
      category: Value(category),
      facultyName: Value(facultyName),
      slot: Value(slot),
      roomNo: Value(roomNo),
      hoursConducted: Value(hoursConducted),
      hoursAbsent: Value(hoursAbsent),
      attendancePct: Value(attendancePct),
      source: Value(source),
      updatedAt: Value(updatedAt),
    );
  }

  factory AttendanceCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceCacheData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      courseCode: serializer.fromJson<String>(json['courseCode']),
      courseTitle: serializer.fromJson<String>(json['courseTitle']),
      category: serializer.fromJson<String>(json['category']),
      facultyName: serializer.fromJson<String>(json['facultyName']),
      slot: serializer.fromJson<String>(json['slot']),
      roomNo: serializer.fromJson<String>(json['roomNo']),
      hoursConducted: serializer.fromJson<int>(json['hoursConducted']),
      hoursAbsent: serializer.fromJson<int>(json['hoursAbsent']),
      attendancePct: serializer.fromJson<double>(json['attendancePct']),
      source: serializer.fromJson<String>(json['source']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'courseCode': serializer.toJson<String>(courseCode),
      'courseTitle': serializer.toJson<String>(courseTitle),
      'category': serializer.toJson<String>(category),
      'facultyName': serializer.toJson<String>(facultyName),
      'slot': serializer.toJson<String>(slot),
      'roomNo': serializer.toJson<String>(roomNo),
      'hoursConducted': serializer.toJson<int>(hoursConducted),
      'hoursAbsent': serializer.toJson<int>(hoursAbsent),
      'attendancePct': serializer.toJson<double>(attendancePct),
      'source': serializer.toJson<String>(source),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AttendanceCacheData copyWith(
          {String? academiaEmail,
          String? courseCode,
          String? courseTitle,
          String? category,
          String? facultyName,
          String? slot,
          String? roomNo,
          int? hoursConducted,
          int? hoursAbsent,
          double? attendancePct,
          String? source,
          int? updatedAt}) =>
      AttendanceCacheData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        courseCode: courseCode ?? this.courseCode,
        courseTitle: courseTitle ?? this.courseTitle,
        category: category ?? this.category,
        facultyName: facultyName ?? this.facultyName,
        slot: slot ?? this.slot,
        roomNo: roomNo ?? this.roomNo,
        hoursConducted: hoursConducted ?? this.hoursConducted,
        hoursAbsent: hoursAbsent ?? this.hoursAbsent,
        attendancePct: attendancePct ?? this.attendancePct,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AttendanceCacheData copyWithCompanion(AttendanceCacheCompanion data) {
    return AttendanceCacheData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      courseCode:
          data.courseCode.present ? data.courseCode.value : this.courseCode,
      courseTitle:
          data.courseTitle.present ? data.courseTitle.value : this.courseTitle,
      category: data.category.present ? data.category.value : this.category,
      facultyName:
          data.facultyName.present ? data.facultyName.value : this.facultyName,
      slot: data.slot.present ? data.slot.value : this.slot,
      roomNo: data.roomNo.present ? data.roomNo.value : this.roomNo,
      hoursConducted: data.hoursConducted.present
          ? data.hoursConducted.value
          : this.hoursConducted,
      hoursAbsent:
          data.hoursAbsent.present ? data.hoursAbsent.value : this.hoursAbsent,
      attendancePct: data.attendancePct.present
          ? data.attendancePct.value
          : this.attendancePct,
      source: data.source.present ? data.source.value : this.source,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceCacheData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('courseCode: $courseCode, ')
          ..write('courseTitle: $courseTitle, ')
          ..write('category: $category, ')
          ..write('facultyName: $facultyName, ')
          ..write('slot: $slot, ')
          ..write('roomNo: $roomNo, ')
          ..write('hoursConducted: $hoursConducted, ')
          ..write('hoursAbsent: $hoursAbsent, ')
          ..write('attendancePct: $attendancePct, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      academiaEmail,
      courseCode,
      courseTitle,
      category,
      facultyName,
      slot,
      roomNo,
      hoursConducted,
      hoursAbsent,
      attendancePct,
      source,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceCacheData &&
          other.academiaEmail == this.academiaEmail &&
          other.courseCode == this.courseCode &&
          other.courseTitle == this.courseTitle &&
          other.category == this.category &&
          other.facultyName == this.facultyName &&
          other.slot == this.slot &&
          other.roomNo == this.roomNo &&
          other.hoursConducted == this.hoursConducted &&
          other.hoursAbsent == this.hoursAbsent &&
          other.attendancePct == this.attendancePct &&
          other.source == this.source &&
          other.updatedAt == this.updatedAt);
}

class AttendanceCacheCompanion extends UpdateCompanion<AttendanceCacheData> {
  final Value<String> academiaEmail;
  final Value<String> courseCode;
  final Value<String> courseTitle;
  final Value<String> category;
  final Value<String> facultyName;
  final Value<String> slot;
  final Value<String> roomNo;
  final Value<int> hoursConducted;
  final Value<int> hoursAbsent;
  final Value<double> attendancePct;
  final Value<String> source;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AttendanceCacheCompanion({
    this.academiaEmail = const Value.absent(),
    this.courseCode = const Value.absent(),
    this.courseTitle = const Value.absent(),
    this.category = const Value.absent(),
    this.facultyName = const Value.absent(),
    this.slot = const Value.absent(),
    this.roomNo = const Value.absent(),
    this.hoursConducted = const Value.absent(),
    this.hoursAbsent = const Value.absent(),
    this.attendancePct = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttendanceCacheCompanion.insert({
    required String academiaEmail,
    required String courseCode,
    this.courseTitle = const Value.absent(),
    this.category = const Value.absent(),
    this.facultyName = const Value.absent(),
    this.slot = const Value.absent(),
    this.roomNo = const Value.absent(),
    this.hoursConducted = const Value.absent(),
    this.hoursAbsent = const Value.absent(),
    this.attendancePct = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : academiaEmail = Value(academiaEmail),
        courseCode = Value(courseCode);
  static Insertable<AttendanceCacheData> custom({
    Expression<String>? academiaEmail,
    Expression<String>? courseCode,
    Expression<String>? courseTitle,
    Expression<String>? category,
    Expression<String>? facultyName,
    Expression<String>? slot,
    Expression<String>? roomNo,
    Expression<int>? hoursConducted,
    Expression<int>? hoursAbsent,
    Expression<double>? attendancePct,
    Expression<String>? source,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (courseCode != null) 'course_code': courseCode,
      if (courseTitle != null) 'course_title': courseTitle,
      if (category != null) 'category': category,
      if (facultyName != null) 'faculty_name': facultyName,
      if (slot != null) 'slot': slot,
      if (roomNo != null) 'room_no': roomNo,
      if (hoursConducted != null) 'hours_conducted': hoursConducted,
      if (hoursAbsent != null) 'hours_absent': hoursAbsent,
      if (attendancePct != null) 'attendance_pct': attendancePct,
      if (source != null) 'source': source,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttendanceCacheCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? courseCode,
      Value<String>? courseTitle,
      Value<String>? category,
      Value<String>? facultyName,
      Value<String>? slot,
      Value<String>? roomNo,
      Value<int>? hoursConducted,
      Value<int>? hoursAbsent,
      Value<double>? attendancePct,
      Value<String>? source,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return AttendanceCacheCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      category: category ?? this.category,
      facultyName: facultyName ?? this.facultyName,
      slot: slot ?? this.slot,
      roomNo: roomNo ?? this.roomNo,
      hoursConducted: hoursConducted ?? this.hoursConducted,
      hoursAbsent: hoursAbsent ?? this.hoursAbsent,
      attendancePct: attendancePct ?? this.attendancePct,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (courseCode.present) {
      map['course_code'] = Variable<String>(courseCode.value);
    }
    if (courseTitle.present) {
      map['course_title'] = Variable<String>(courseTitle.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (facultyName.present) {
      map['faculty_name'] = Variable<String>(facultyName.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (roomNo.present) {
      map['room_no'] = Variable<String>(roomNo.value);
    }
    if (hoursConducted.present) {
      map['hours_conducted'] = Variable<int>(hoursConducted.value);
    }
    if (hoursAbsent.present) {
      map['hours_absent'] = Variable<int>(hoursAbsent.value);
    }
    if (attendancePct.present) {
      map['attendance_pct'] = Variable<double>(attendancePct.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceCacheCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('courseCode: $courseCode, ')
          ..write('courseTitle: $courseTitle, ')
          ..write('category: $category, ')
          ..write('facultyName: $facultyName, ')
          ..write('slot: $slot, ')
          ..write('roomNo: $roomNo, ')
          ..write('hoursConducted: $hoursConducted, ')
          ..write('hoursAbsent: $hoursAbsent, ')
          ..write('attendancePct: $attendancePct, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendanceSnapshotsTable extends AttendanceSnapshots
    with TableInfo<$AttendanceSnapshotsTable, AttendanceSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _snapshotDateMeta =
      const VerificationMeta('snapshotDate');
  @override
  late final GeneratedColumn<String> snapshotDate = GeneratedColumn<String>(
      'snapshot_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _overallPercentageMeta =
      const VerificationMeta('overallPercentage');
  @override
  late final GeneratedColumn<double> overallPercentage =
      GeneratedColumn<double>('overall_percentage', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _weightedPercentageMeta =
      const VerificationMeta('weightedPercentage');
  @override
  late final GeneratedColumn<double> weightedPercentage =
      GeneratedColumn<double>('weighted_percentage', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _subjectsJsonMeta =
      const VerificationMeta('subjectsJson');
  @override
  late final GeneratedColumn<String> subjectsJson = GeneratedColumn<String>(
      'subjects_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _totalClassesMeta =
      const VerificationMeta('totalClasses');
  @override
  late final GeneratedColumn<int> totalClasses = GeneratedColumn<int>(
      'total_classes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _attendedClassesMeta =
      const VerificationMeta('attendedClasses');
  @override
  late final GeneratedColumn<int> attendedClasses = GeneratedColumn<int>(
      'attended_classes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        academiaEmail,
        snapshotDate,
        overallPercentage,
        weightedPercentage,
        subjectsJson,
        totalClasses,
        attendedClasses,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<AttendanceSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
          _snapshotDateMeta,
          snapshotDate.isAcceptableOrUnknown(
              data['snapshot_date']!, _snapshotDateMeta));
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('overall_percentage')) {
      context.handle(
          _overallPercentageMeta,
          overallPercentage.isAcceptableOrUnknown(
              data['overall_percentage']!, _overallPercentageMeta));
    }
    if (data.containsKey('weighted_percentage')) {
      context.handle(
          _weightedPercentageMeta,
          weightedPercentage.isAcceptableOrUnknown(
              data['weighted_percentage']!, _weightedPercentageMeta));
    }
    if (data.containsKey('subjects_json')) {
      context.handle(
          _subjectsJsonMeta,
          subjectsJson.isAcceptableOrUnknown(
              data['subjects_json']!, _subjectsJsonMeta));
    }
    if (data.containsKey('total_classes')) {
      context.handle(
          _totalClassesMeta,
          totalClasses.isAcceptableOrUnknown(
              data['total_classes']!, _totalClassesMeta));
    }
    if (data.containsKey('attended_classes')) {
      context.handle(
          _attendedClassesMeta,
          attendedClasses.isAcceptableOrUnknown(
              data['attended_classes']!, _attendedClassesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {academiaEmail, snapshotDate},
      ];
  @override
  AttendanceSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      snapshotDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}snapshot_date'])!,
      overallPercentage: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}overall_percentage'])!,
      weightedPercentage: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}weighted_percentage'])!,
      subjectsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subjects_json'])!,
      totalClasses: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_classes'])!,
      attendedClasses: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attended_classes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AttendanceSnapshotsTable createAlias(String alias) {
    return $AttendanceSnapshotsTable(attachedDatabase, alias);
  }
}

class AttendanceSnapshot extends DataClass
    implements Insertable<AttendanceSnapshot> {
  final int id;
  final String academiaEmail;
  final String snapshotDate;
  final double overallPercentage;
  final double weightedPercentage;
  final String subjectsJson;
  final int totalClasses;
  final int attendedClasses;
  final int createdAt;
  const AttendanceSnapshot(
      {required this.id,
      required this.academiaEmail,
      required this.snapshotDate,
      required this.overallPercentage,
      required this.weightedPercentage,
      required this.subjectsJson,
      required this.totalClasses,
      required this.attendedClasses,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['academia_email'] = Variable<String>(academiaEmail);
    map['snapshot_date'] = Variable<String>(snapshotDate);
    map['overall_percentage'] = Variable<double>(overallPercentage);
    map['weighted_percentage'] = Variable<double>(weightedPercentage);
    map['subjects_json'] = Variable<String>(subjectsJson);
    map['total_classes'] = Variable<int>(totalClasses);
    map['attended_classes'] = Variable<int>(attendedClasses);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AttendanceSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceSnapshotsCompanion(
      id: Value(id),
      academiaEmail: Value(academiaEmail),
      snapshotDate: Value(snapshotDate),
      overallPercentage: Value(overallPercentage),
      weightedPercentage: Value(weightedPercentage),
      subjectsJson: Value(subjectsJson),
      totalClasses: Value(totalClasses),
      attendedClasses: Value(attendedClasses),
      createdAt: Value(createdAt),
    );
  }

  factory AttendanceSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceSnapshot(
      id: serializer.fromJson<int>(json['id']),
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      snapshotDate: serializer.fromJson<String>(json['snapshotDate']),
      overallPercentage: serializer.fromJson<double>(json['overallPercentage']),
      weightedPercentage:
          serializer.fromJson<double>(json['weightedPercentage']),
      subjectsJson: serializer.fromJson<String>(json['subjectsJson']),
      totalClasses: serializer.fromJson<int>(json['totalClasses']),
      attendedClasses: serializer.fromJson<int>(json['attendedClasses']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'snapshotDate': serializer.toJson<String>(snapshotDate),
      'overallPercentage': serializer.toJson<double>(overallPercentage),
      'weightedPercentage': serializer.toJson<double>(weightedPercentage),
      'subjectsJson': serializer.toJson<String>(subjectsJson),
      'totalClasses': serializer.toJson<int>(totalClasses),
      'attendedClasses': serializer.toJson<int>(attendedClasses),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AttendanceSnapshot copyWith(
          {int? id,
          String? academiaEmail,
          String? snapshotDate,
          double? overallPercentage,
          double? weightedPercentage,
          String? subjectsJson,
          int? totalClasses,
          int? attendedClasses,
          int? createdAt}) =>
      AttendanceSnapshot(
        id: id ?? this.id,
        academiaEmail: academiaEmail ?? this.academiaEmail,
        snapshotDate: snapshotDate ?? this.snapshotDate,
        overallPercentage: overallPercentage ?? this.overallPercentage,
        weightedPercentage: weightedPercentage ?? this.weightedPercentage,
        subjectsJson: subjectsJson ?? this.subjectsJson,
        totalClasses: totalClasses ?? this.totalClasses,
        attendedClasses: attendedClasses ?? this.attendedClasses,
        createdAt: createdAt ?? this.createdAt,
      );
  AttendanceSnapshot copyWithCompanion(AttendanceSnapshotsCompanion data) {
    return AttendanceSnapshot(
      id: data.id.present ? data.id.value : this.id,
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      overallPercentage: data.overallPercentage.present
          ? data.overallPercentage.value
          : this.overallPercentage,
      weightedPercentage: data.weightedPercentage.present
          ? data.weightedPercentage.value
          : this.weightedPercentage,
      subjectsJson: data.subjectsJson.present
          ? data.subjectsJson.value
          : this.subjectsJson,
      totalClasses: data.totalClasses.present
          ? data.totalClasses.value
          : this.totalClasses,
      attendedClasses: data.attendedClasses.present
          ? data.attendedClasses.value
          : this.attendedClasses,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSnapshot(')
          ..write('id: $id, ')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('overallPercentage: $overallPercentage, ')
          ..write('weightedPercentage: $weightedPercentage, ')
          ..write('subjectsJson: $subjectsJson, ')
          ..write('totalClasses: $totalClasses, ')
          ..write('attendedClasses: $attendedClasses, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      academiaEmail,
      snapshotDate,
      overallPercentage,
      weightedPercentage,
      subjectsJson,
      totalClasses,
      attendedClasses,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceSnapshot &&
          other.id == this.id &&
          other.academiaEmail == this.academiaEmail &&
          other.snapshotDate == this.snapshotDate &&
          other.overallPercentage == this.overallPercentage &&
          other.weightedPercentage == this.weightedPercentage &&
          other.subjectsJson == this.subjectsJson &&
          other.totalClasses == this.totalClasses &&
          other.attendedClasses == this.attendedClasses &&
          other.createdAt == this.createdAt);
}

class AttendanceSnapshotsCompanion extends UpdateCompanion<AttendanceSnapshot> {
  final Value<int> id;
  final Value<String> academiaEmail;
  final Value<String> snapshotDate;
  final Value<double> overallPercentage;
  final Value<double> weightedPercentage;
  final Value<String> subjectsJson;
  final Value<int> totalClasses;
  final Value<int> attendedClasses;
  final Value<int> createdAt;
  const AttendanceSnapshotsCompanion({
    this.id = const Value.absent(),
    this.academiaEmail = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.overallPercentage = const Value.absent(),
    this.weightedPercentage = const Value.absent(),
    this.subjectsJson = const Value.absent(),
    this.totalClasses = const Value.absent(),
    this.attendedClasses = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttendanceSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String academiaEmail,
    required String snapshotDate,
    this.overallPercentage = const Value.absent(),
    this.weightedPercentage = const Value.absent(),
    this.subjectsJson = const Value.absent(),
    this.totalClasses = const Value.absent(),
    this.attendedClasses = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : academiaEmail = Value(academiaEmail),
        snapshotDate = Value(snapshotDate);
  static Insertable<AttendanceSnapshot> custom({
    Expression<int>? id,
    Expression<String>? academiaEmail,
    Expression<String>? snapshotDate,
    Expression<double>? overallPercentage,
    Expression<double>? weightedPercentage,
    Expression<String>? subjectsJson,
    Expression<int>? totalClasses,
    Expression<int>? attendedClasses,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (overallPercentage != null) 'overall_percentage': overallPercentage,
      if (weightedPercentage != null) 'weighted_percentage': weightedPercentage,
      if (subjectsJson != null) 'subjects_json': subjectsJson,
      if (totalClasses != null) 'total_classes': totalClasses,
      if (attendedClasses != null) 'attended_classes': attendedClasses,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttendanceSnapshotsCompanion copyWith(
      {Value<int>? id,
      Value<String>? academiaEmail,
      Value<String>? snapshotDate,
      Value<double>? overallPercentage,
      Value<double>? weightedPercentage,
      Value<String>? subjectsJson,
      Value<int>? totalClasses,
      Value<int>? attendedClasses,
      Value<int>? createdAt}) {
    return AttendanceSnapshotsCompanion(
      id: id ?? this.id,
      academiaEmail: academiaEmail ?? this.academiaEmail,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      overallPercentage: overallPercentage ?? this.overallPercentage,
      weightedPercentage: weightedPercentage ?? this.weightedPercentage,
      subjectsJson: subjectsJson ?? this.subjectsJson,
      totalClasses: totalClasses ?? this.totalClasses,
      attendedClasses: attendedClasses ?? this.attendedClasses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<String>(snapshotDate.value);
    }
    if (overallPercentage.present) {
      map['overall_percentage'] = Variable<double>(overallPercentage.value);
    }
    if (weightedPercentage.present) {
      map['weighted_percentage'] = Variable<double>(weightedPercentage.value);
    }
    if (subjectsJson.present) {
      map['subjects_json'] = Variable<String>(subjectsJson.value);
    }
    if (totalClasses.present) {
      map['total_classes'] = Variable<int>(totalClasses.value);
    }
    if (attendedClasses.present) {
      map['attended_classes'] = Variable<int>(attendedClasses.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('overallPercentage: $overallPercentage, ')
          ..write('weightedPercentage: $weightedPercentage, ')
          ..write('subjectsJson: $subjectsJson, ')
          ..write('totalClasses: $totalClasses, ')
          ..write('attendedClasses: $attendedClasses, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TimetableCacheTable extends TimetableCache
    with TableInfo<$TimetableCacheTable, TimetableCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimetableCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _batchMeta = const VerificationMeta('batch');
  @override
  late final GeneratedColumn<String> batch = GeneratedColumn<String>(
      'batch', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _coursesJsonMeta =
      const VerificationMeta('coursesJson');
  @override
  late final GeneratedColumn<String> coursesJson = GeneratedColumn<String>(
      'courses_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _advisorsJsonMeta =
      const VerificationMeta('advisorsJson');
  @override
  late final GeneratedColumn<String> advisorsJson = GeneratedColumn<String>(
      'advisors_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [academiaEmail, batch, coursesJson, advisorsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timetable_cache';
  @override
  VerificationContext validateIntegrity(Insertable<TimetableCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('batch')) {
      context.handle(
          _batchMeta, batch.isAcceptableOrUnknown(data['batch']!, _batchMeta));
    }
    if (data.containsKey('courses_json')) {
      context.handle(
          _coursesJsonMeta,
          coursesJson.isAcceptableOrUnknown(
              data['courses_json']!, _coursesJsonMeta));
    }
    if (data.containsKey('advisors_json')) {
      context.handle(
          _advisorsJsonMeta,
          advisorsJson.isAcceptableOrUnknown(
              data['advisors_json']!, _advisorsJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail};
  @override
  TimetableCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimetableCacheData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      batch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch'])!,
      coursesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}courses_json'])!,
      advisorsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}advisors_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TimetableCacheTable createAlias(String alias) {
    return $TimetableCacheTable(attachedDatabase, alias);
  }
}

class TimetableCacheData extends DataClass
    implements Insertable<TimetableCacheData> {
  final String academiaEmail;
  final String batch;
  final String coursesJson;
  final String advisorsJson;
  final int updatedAt;
  const TimetableCacheData(
      {required this.academiaEmail,
      required this.batch,
      required this.coursesJson,
      required this.advisorsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['batch'] = Variable<String>(batch);
    map['courses_json'] = Variable<String>(coursesJson);
    map['advisors_json'] = Variable<String>(advisorsJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TimetableCacheCompanion toCompanion(bool nullToAbsent) {
    return TimetableCacheCompanion(
      academiaEmail: Value(academiaEmail),
      batch: Value(batch),
      coursesJson: Value(coursesJson),
      advisorsJson: Value(advisorsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory TimetableCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimetableCacheData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      batch: serializer.fromJson<String>(json['batch']),
      coursesJson: serializer.fromJson<String>(json['coursesJson']),
      advisorsJson: serializer.fromJson<String>(json['advisorsJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'batch': serializer.toJson<String>(batch),
      'coursesJson': serializer.toJson<String>(coursesJson),
      'advisorsJson': serializer.toJson<String>(advisorsJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TimetableCacheData copyWith(
          {String? academiaEmail,
          String? batch,
          String? coursesJson,
          String? advisorsJson,
          int? updatedAt}) =>
      TimetableCacheData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        batch: batch ?? this.batch,
        coursesJson: coursesJson ?? this.coursesJson,
        advisorsJson: advisorsJson ?? this.advisorsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TimetableCacheData copyWithCompanion(TimetableCacheCompanion data) {
    return TimetableCacheData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      batch: data.batch.present ? data.batch.value : this.batch,
      coursesJson:
          data.coursesJson.present ? data.coursesJson.value : this.coursesJson,
      advisorsJson: data.advisorsJson.present
          ? data.advisorsJson.value
          : this.advisorsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimetableCacheData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('batch: $batch, ')
          ..write('coursesJson: $coursesJson, ')
          ..write('advisorsJson: $advisorsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(academiaEmail, batch, coursesJson, advisorsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimetableCacheData &&
          other.academiaEmail == this.academiaEmail &&
          other.batch == this.batch &&
          other.coursesJson == this.coursesJson &&
          other.advisorsJson == this.advisorsJson &&
          other.updatedAt == this.updatedAt);
}

class TimetableCacheCompanion extends UpdateCompanion<TimetableCacheData> {
  final Value<String> academiaEmail;
  final Value<String> batch;
  final Value<String> coursesJson;
  final Value<String> advisorsJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TimetableCacheCompanion({
    this.academiaEmail = const Value.absent(),
    this.batch = const Value.absent(),
    this.coursesJson = const Value.absent(),
    this.advisorsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimetableCacheCompanion.insert({
    required String academiaEmail,
    this.batch = const Value.absent(),
    this.coursesJson = const Value.absent(),
    this.advisorsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : academiaEmail = Value(academiaEmail);
  static Insertable<TimetableCacheData> custom({
    Expression<String>? academiaEmail,
    Expression<String>? batch,
    Expression<String>? coursesJson,
    Expression<String>? advisorsJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (batch != null) 'batch': batch,
      if (coursesJson != null) 'courses_json': coursesJson,
      if (advisorsJson != null) 'advisors_json': advisorsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimetableCacheCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? batch,
      Value<String>? coursesJson,
      Value<String>? advisorsJson,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return TimetableCacheCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      batch: batch ?? this.batch,
      coursesJson: coursesJson ?? this.coursesJson,
      advisorsJson: advisorsJson ?? this.advisorsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (batch.present) {
      map['batch'] = Variable<String>(batch.value);
    }
    if (coursesJson.present) {
      map['courses_json'] = Variable<String>(coursesJson.value);
    }
    if (advisorsJson.present) {
      map['advisors_json'] = Variable<String>(advisorsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimetableCacheCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('batch: $batch, ')
          ..write('coursesJson: $coursesJson, ')
          ..write('advisorsJson: $advisorsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarksCacheTable extends MarksCache
    with TableInfo<$MarksCacheTable, MarksCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarksCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseCodeMeta =
      const VerificationMeta('courseCode');
  @override
  late final GeneratedColumn<String> courseCode = GeneratedColumn<String>(
      'course_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseTitleMeta =
      const VerificationMeta('courseTitle');
  @override
  late final GeneratedColumn<String> courseTitle = GeneratedColumn<String>(
      'course_title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _courseTypeMeta =
      const VerificationMeta('courseType');
  @override
  late final GeneratedColumn<String> courseType = GeneratedColumn<String>(
      'course_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('academia'));
  static const VerificationMeta _testsJsonMeta =
      const VerificationMeta('testsJson');
  @override
  late final GeneratedColumn<String> testsJson = GeneratedColumn<String>(
      'tests_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        academiaEmail,
        courseCode,
        courseTitle,
        courseType,
        source,
        testsJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'marks_cache';
  @override
  VerificationContext validateIntegrity(Insertable<MarksCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('course_code')) {
      context.handle(
          _courseCodeMeta,
          courseCode.isAcceptableOrUnknown(
              data['course_code']!, _courseCodeMeta));
    } else if (isInserting) {
      context.missing(_courseCodeMeta);
    }
    if (data.containsKey('course_title')) {
      context.handle(
          _courseTitleMeta,
          courseTitle.isAcceptableOrUnknown(
              data['course_title']!, _courseTitleMeta));
    }
    if (data.containsKey('course_type')) {
      context.handle(
          _courseTypeMeta,
          courseType.isAcceptableOrUnknown(
              data['course_type']!, _courseTypeMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('tests_json')) {
      context.handle(_testsJsonMeta,
          testsJson.isAcceptableOrUnknown(data['tests_json']!, _testsJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail, courseCode, source};
  @override
  MarksCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarksCacheData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      courseCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_code'])!,
      courseTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_title'])!,
      courseType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_type'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      testsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tests_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MarksCacheTable createAlias(String alias) {
    return $MarksCacheTable(attachedDatabase, alias);
  }
}

class MarksCacheData extends DataClass implements Insertable<MarksCacheData> {
  final String academiaEmail;
  final String courseCode;
  final String courseTitle;
  final String courseType;
  final String source;
  final String testsJson;
  final int updatedAt;
  const MarksCacheData(
      {required this.academiaEmail,
      required this.courseCode,
      required this.courseTitle,
      required this.courseType,
      required this.source,
      required this.testsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['course_code'] = Variable<String>(courseCode);
    map['course_title'] = Variable<String>(courseTitle);
    map['course_type'] = Variable<String>(courseType);
    map['source'] = Variable<String>(source);
    map['tests_json'] = Variable<String>(testsJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MarksCacheCompanion toCompanion(bool nullToAbsent) {
    return MarksCacheCompanion(
      academiaEmail: Value(academiaEmail),
      courseCode: Value(courseCode),
      courseTitle: Value(courseTitle),
      courseType: Value(courseType),
      source: Value(source),
      testsJson: Value(testsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory MarksCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarksCacheData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      courseCode: serializer.fromJson<String>(json['courseCode']),
      courseTitle: serializer.fromJson<String>(json['courseTitle']),
      courseType: serializer.fromJson<String>(json['courseType']),
      source: serializer.fromJson<String>(json['source']),
      testsJson: serializer.fromJson<String>(json['testsJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'courseCode': serializer.toJson<String>(courseCode),
      'courseTitle': serializer.toJson<String>(courseTitle),
      'courseType': serializer.toJson<String>(courseType),
      'source': serializer.toJson<String>(source),
      'testsJson': serializer.toJson<String>(testsJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MarksCacheData copyWith(
          {String? academiaEmail,
          String? courseCode,
          String? courseTitle,
          String? courseType,
          String? source,
          String? testsJson,
          int? updatedAt}) =>
      MarksCacheData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        courseCode: courseCode ?? this.courseCode,
        courseTitle: courseTitle ?? this.courseTitle,
        courseType: courseType ?? this.courseType,
        source: source ?? this.source,
        testsJson: testsJson ?? this.testsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MarksCacheData copyWithCompanion(MarksCacheCompanion data) {
    return MarksCacheData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      courseCode:
          data.courseCode.present ? data.courseCode.value : this.courseCode,
      courseTitle:
          data.courseTitle.present ? data.courseTitle.value : this.courseTitle,
      courseType:
          data.courseType.present ? data.courseType.value : this.courseType,
      source: data.source.present ? data.source.value : this.source,
      testsJson: data.testsJson.present ? data.testsJson.value : this.testsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarksCacheData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('courseCode: $courseCode, ')
          ..write('courseTitle: $courseTitle, ')
          ..write('courseType: $courseType, ')
          ..write('source: $source, ')
          ..write('testsJson: $testsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(academiaEmail, courseCode, courseTitle,
      courseType, source, testsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarksCacheData &&
          other.academiaEmail == this.academiaEmail &&
          other.courseCode == this.courseCode &&
          other.courseTitle == this.courseTitle &&
          other.courseType == this.courseType &&
          other.source == this.source &&
          other.testsJson == this.testsJson &&
          other.updatedAt == this.updatedAt);
}

class MarksCacheCompanion extends UpdateCompanion<MarksCacheData> {
  final Value<String> academiaEmail;
  final Value<String> courseCode;
  final Value<String> courseTitle;
  final Value<String> courseType;
  final Value<String> source;
  final Value<String> testsJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MarksCacheCompanion({
    this.academiaEmail = const Value.absent(),
    this.courseCode = const Value.absent(),
    this.courseTitle = const Value.absent(),
    this.courseType = const Value.absent(),
    this.source = const Value.absent(),
    this.testsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarksCacheCompanion.insert({
    required String academiaEmail,
    required String courseCode,
    this.courseTitle = const Value.absent(),
    this.courseType = const Value.absent(),
    this.source = const Value.absent(),
    this.testsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : academiaEmail = Value(academiaEmail),
        courseCode = Value(courseCode);
  static Insertable<MarksCacheData> custom({
    Expression<String>? academiaEmail,
    Expression<String>? courseCode,
    Expression<String>? courseTitle,
    Expression<String>? courseType,
    Expression<String>? source,
    Expression<String>? testsJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (courseCode != null) 'course_code': courseCode,
      if (courseTitle != null) 'course_title': courseTitle,
      if (courseType != null) 'course_type': courseType,
      if (source != null) 'source': source,
      if (testsJson != null) 'tests_json': testsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarksCacheCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? courseCode,
      Value<String>? courseTitle,
      Value<String>? courseType,
      Value<String>? source,
      Value<String>? testsJson,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return MarksCacheCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      courseType: courseType ?? this.courseType,
      source: source ?? this.source,
      testsJson: testsJson ?? this.testsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (courseCode.present) {
      map['course_code'] = Variable<String>(courseCode.value);
    }
    if (courseTitle.present) {
      map['course_title'] = Variable<String>(courseTitle.value);
    }
    if (courseType.present) {
      map['course_type'] = Variable<String>(courseType.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (testsJson.present) {
      map['tests_json'] = Variable<String>(testsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarksCacheCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('courseCode: $courseCode, ')
          ..write('courseTitle: $courseTitle, ')
          ..write('courseType: $courseType, ')
          ..write('source: $source, ')
          ..write('testsJson: $testsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarCacheTable extends CalendarCache
    with TableInfo<$CalendarCacheTable, CalendarCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterMeta =
      const VerificationMeta('semester');
  @override
  late final GeneratedColumn<String> semester = GeneratedColumn<String>(
      'semester', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _monthsJsonMeta =
      const VerificationMeta('monthsJson');
  @override
  late final GeneratedColumn<String> monthsJson = GeneratedColumn<String>(
      'months_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [academiaEmail, semester, title, monthsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_cache';
  @override
  VerificationContext validateIntegrity(Insertable<CalendarCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('semester')) {
      context.handle(_semesterMeta,
          semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta));
    } else if (isInserting) {
      context.missing(_semesterMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('months_json')) {
      context.handle(
          _monthsJsonMeta,
          monthsJson.isAcceptableOrUnknown(
              data['months_json']!, _monthsJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail, semester};
  @override
  CalendarCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarCacheData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      semester: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      monthsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}months_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CalendarCacheTable createAlias(String alias) {
    return $CalendarCacheTable(attachedDatabase, alias);
  }
}

class CalendarCacheData extends DataClass
    implements Insertable<CalendarCacheData> {
  final String academiaEmail;
  final String semester;
  final String title;
  final String monthsJson;
  final int updatedAt;
  const CalendarCacheData(
      {required this.academiaEmail,
      required this.semester,
      required this.title,
      required this.monthsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['semester'] = Variable<String>(semester);
    map['title'] = Variable<String>(title);
    map['months_json'] = Variable<String>(monthsJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CalendarCacheCompanion toCompanion(bool nullToAbsent) {
    return CalendarCacheCompanion(
      academiaEmail: Value(academiaEmail),
      semester: Value(semester),
      title: Value(title),
      monthsJson: Value(monthsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarCacheData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      semester: serializer.fromJson<String>(json['semester']),
      title: serializer.fromJson<String>(json['title']),
      monthsJson: serializer.fromJson<String>(json['monthsJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'semester': serializer.toJson<String>(semester),
      'title': serializer.toJson<String>(title),
      'monthsJson': serializer.toJson<String>(monthsJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CalendarCacheData copyWith(
          {String? academiaEmail,
          String? semester,
          String? title,
          String? monthsJson,
          int? updatedAt}) =>
      CalendarCacheData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        semester: semester ?? this.semester,
        title: title ?? this.title,
        monthsJson: monthsJson ?? this.monthsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CalendarCacheData copyWithCompanion(CalendarCacheCompanion data) {
    return CalendarCacheData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      semester: data.semester.present ? data.semester.value : this.semester,
      title: data.title.present ? data.title.value : this.title,
      monthsJson:
          data.monthsJson.present ? data.monthsJson.value : this.monthsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCacheData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('semester: $semester, ')
          ..write('title: $title, ')
          ..write('monthsJson: $monthsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(academiaEmail, semester, title, monthsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarCacheData &&
          other.academiaEmail == this.academiaEmail &&
          other.semester == this.semester &&
          other.title == this.title &&
          other.monthsJson == this.monthsJson &&
          other.updatedAt == this.updatedAt);
}

class CalendarCacheCompanion extends UpdateCompanion<CalendarCacheData> {
  final Value<String> academiaEmail;
  final Value<String> semester;
  final Value<String> title;
  final Value<String> monthsJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CalendarCacheCompanion({
    this.academiaEmail = const Value.absent(),
    this.semester = const Value.absent(),
    this.title = const Value.absent(),
    this.monthsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarCacheCompanion.insert({
    required String academiaEmail,
    required String semester,
    this.title = const Value.absent(),
    this.monthsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : academiaEmail = Value(academiaEmail),
        semester = Value(semester);
  static Insertable<CalendarCacheData> custom({
    Expression<String>? academiaEmail,
    Expression<String>? semester,
    Expression<String>? title,
    Expression<String>? monthsJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (semester != null) 'semester': semester,
      if (title != null) 'title': title,
      if (monthsJson != null) 'months_json': monthsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarCacheCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? semester,
      Value<String>? title,
      Value<String>? monthsJson,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return CalendarCacheCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      semester: semester ?? this.semester,
      title: title ?? this.title,
      monthsJson: monthsJson ?? this.monthsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (semester.present) {
      map['semester'] = Variable<String>(semester.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (monthsJson.present) {
      map['months_json'] = Variable<String>(monthsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCacheCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('semester: $semester, ')
          ..write('title: $title, ')
          ..write('monthsJson: $monthsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FacultyCacheTable extends FacultyCache
    with TableInfo<$FacultyCacheTable, FacultyCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FacultyCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _designationMeta =
      const VerificationMeta('designation');
  @override
  late final GeneratedColumn<String> designation = GeneratedColumn<String>(
      'designation', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _departmentMeta =
      const VerificationMeta('department');
  @override
  late final GeneratedColumn<String> department = GeneratedColumn<String>(
      'department', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _emailAddressMeta =
      const VerificationMeta('emailAddress');
  @override
  late final GeneratedColumn<String> emailAddress = GeneratedColumn<String>(
      'email_address', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _campusMeta = const VerificationMeta('campus');
  @override
  late final GeneratedColumn<String> campus = GeneratedColumn<String>(
      'campus', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _experienceMeta =
      const VerificationMeta('experience');
  @override
  late final GeneratedColumn<String> experience = GeneratedColumn<String>(
      'experience', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _researchInterestMeta =
      const VerificationMeta('researchInterest');
  @override
  late final GeneratedColumn<String> researchInterest = GeneratedColumn<String>(
      'research_interest', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _coursesMeta =
      const VerificationMeta('courses');
  @override
  late final GeneratedColumn<String> courses = GeneratedColumn<String>(
      'courses', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _educationMeta =
      const VerificationMeta('education');
  @override
  late final GeneratedColumn<String> education = GeneratedColumn<String>(
      'education', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _publicationsMeta =
      const VerificationMeta('publications');
  @override
  late final GeneratedColumn<String> publications = GeneratedColumn<String>(
      'publications', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _awardsMeta = const VerificationMeta('awards');
  @override
  late final GeneratedColumn<String> awards = GeneratedColumn<String>(
      'awards', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _workshopsMeta =
      const VerificationMeta('workshops');
  @override
  late final GeneratedColumn<String> workshops = GeneratedColumn<String>(
      'workshops', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _workExperienceMeta =
      const VerificationMeta('workExperience');
  @override
  late final GeneratedColumn<String> workExperience = GeneratedColumn<String>(
      'work_experience', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _membershipsMeta =
      const VerificationMeta('memberships');
  @override
  late final GeneratedColumn<String> memberships = GeneratedColumn<String>(
      'memberships', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _responsibilitiesMeta =
      const VerificationMeta('responsibilities');
  @override
  late final GeneratedColumn<String> responsibilities = GeneratedColumn<String>(
      'responsibilities', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _profileUrlMeta =
      const VerificationMeta('profileUrl');
  @override
  late final GeneratedColumn<String> profileUrl = GeneratedColumn<String>(
      'profile_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        slug,
        name,
        photoUrl,
        designation,
        department,
        emailAddress,
        campus,
        experience,
        researchInterest,
        courses,
        education,
        publications,
        awards,
        workshops,
        workExperience,
        memberships,
        responsibilities,
        profileUrl,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'faculty_cache';
  @override
  VerificationContext validateIntegrity(Insertable<FacultyCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('designation')) {
      context.handle(
          _designationMeta,
          designation.isAcceptableOrUnknown(
              data['designation']!, _designationMeta));
    }
    if (data.containsKey('department')) {
      context.handle(
          _departmentMeta,
          department.isAcceptableOrUnknown(
              data['department']!, _departmentMeta));
    }
    if (data.containsKey('email_address')) {
      context.handle(
          _emailAddressMeta,
          emailAddress.isAcceptableOrUnknown(
              data['email_address']!, _emailAddressMeta));
    }
    if (data.containsKey('campus')) {
      context.handle(_campusMeta,
          campus.isAcceptableOrUnknown(data['campus']!, _campusMeta));
    }
    if (data.containsKey('experience')) {
      context.handle(
          _experienceMeta,
          experience.isAcceptableOrUnknown(
              data['experience']!, _experienceMeta));
    }
    if (data.containsKey('research_interest')) {
      context.handle(
          _researchInterestMeta,
          researchInterest.isAcceptableOrUnknown(
              data['research_interest']!, _researchInterestMeta));
    }
    if (data.containsKey('courses')) {
      context.handle(_coursesMeta,
          courses.isAcceptableOrUnknown(data['courses']!, _coursesMeta));
    }
    if (data.containsKey('education')) {
      context.handle(_educationMeta,
          education.isAcceptableOrUnknown(data['education']!, _educationMeta));
    }
    if (data.containsKey('publications')) {
      context.handle(
          _publicationsMeta,
          publications.isAcceptableOrUnknown(
              data['publications']!, _publicationsMeta));
    }
    if (data.containsKey('awards')) {
      context.handle(_awardsMeta,
          awards.isAcceptableOrUnknown(data['awards']!, _awardsMeta));
    }
    if (data.containsKey('workshops')) {
      context.handle(_workshopsMeta,
          workshops.isAcceptableOrUnknown(data['workshops']!, _workshopsMeta));
    }
    if (data.containsKey('work_experience')) {
      context.handle(
          _workExperienceMeta,
          workExperience.isAcceptableOrUnknown(
              data['work_experience']!, _workExperienceMeta));
    }
    if (data.containsKey('memberships')) {
      context.handle(
          _membershipsMeta,
          memberships.isAcceptableOrUnknown(
              data['memberships']!, _membershipsMeta));
    }
    if (data.containsKey('responsibilities')) {
      context.handle(
          _responsibilitiesMeta,
          responsibilities.isAcceptableOrUnknown(
              data['responsibilities']!, _responsibilitiesMeta));
    }
    if (data.containsKey('profile_url')) {
      context.handle(
          _profileUrlMeta,
          profileUrl.isAcceptableOrUnknown(
              data['profile_url']!, _profileUrlMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slug};
  @override
  FacultyCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FacultyCacheData(
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url'])!,
      designation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}designation'])!,
      department: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}department'])!,
      emailAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email_address'])!,
      campus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}campus'])!,
      experience: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}experience'])!,
      researchInterest: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}research_interest'])!,
      courses: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}courses'])!,
      education: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}education'])!,
      publications: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}publications'])!,
      awards: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}awards'])!,
      workshops: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workshops'])!,
      workExperience: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}work_experience'])!,
      memberships: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memberships'])!,
      responsibilities: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}responsibilities'])!,
      profileUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_url'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $FacultyCacheTable createAlias(String alias) {
    return $FacultyCacheTable(attachedDatabase, alias);
  }
}

class FacultyCacheData extends DataClass
    implements Insertable<FacultyCacheData> {
  final String slug;
  final String name;
  final String photoUrl;
  final String designation;
  final String department;
  final String emailAddress;
  final String campus;
  final String experience;
  final String researchInterest;
  final String courses;
  final String education;
  final String publications;
  final String awards;
  final String workshops;
  final String workExperience;
  final String memberships;
  final String responsibilities;
  final String profileUrl;
  final int cachedAt;
  const FacultyCacheData(
      {required this.slug,
      required this.name,
      required this.photoUrl,
      required this.designation,
      required this.department,
      required this.emailAddress,
      required this.campus,
      required this.experience,
      required this.researchInterest,
      required this.courses,
      required this.education,
      required this.publications,
      required this.awards,
      required this.workshops,
      required this.workExperience,
      required this.memberships,
      required this.responsibilities,
      required this.profileUrl,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slug'] = Variable<String>(slug);
    map['name'] = Variable<String>(name);
    map['photo_url'] = Variable<String>(photoUrl);
    map['designation'] = Variable<String>(designation);
    map['department'] = Variable<String>(department);
    map['email_address'] = Variable<String>(emailAddress);
    map['campus'] = Variable<String>(campus);
    map['experience'] = Variable<String>(experience);
    map['research_interest'] = Variable<String>(researchInterest);
    map['courses'] = Variable<String>(courses);
    map['education'] = Variable<String>(education);
    map['publications'] = Variable<String>(publications);
    map['awards'] = Variable<String>(awards);
    map['workshops'] = Variable<String>(workshops);
    map['work_experience'] = Variable<String>(workExperience);
    map['memberships'] = Variable<String>(memberships);
    map['responsibilities'] = Variable<String>(responsibilities);
    map['profile_url'] = Variable<String>(profileUrl);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  FacultyCacheCompanion toCompanion(bool nullToAbsent) {
    return FacultyCacheCompanion(
      slug: Value(slug),
      name: Value(name),
      photoUrl: Value(photoUrl),
      designation: Value(designation),
      department: Value(department),
      emailAddress: Value(emailAddress),
      campus: Value(campus),
      experience: Value(experience),
      researchInterest: Value(researchInterest),
      courses: Value(courses),
      education: Value(education),
      publications: Value(publications),
      awards: Value(awards),
      workshops: Value(workshops),
      workExperience: Value(workExperience),
      memberships: Value(memberships),
      responsibilities: Value(responsibilities),
      profileUrl: Value(profileUrl),
      cachedAt: Value(cachedAt),
    );
  }

  factory FacultyCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FacultyCacheData(
      slug: serializer.fromJson<String>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      photoUrl: serializer.fromJson<String>(json['photoUrl']),
      designation: serializer.fromJson<String>(json['designation']),
      department: serializer.fromJson<String>(json['department']),
      emailAddress: serializer.fromJson<String>(json['emailAddress']),
      campus: serializer.fromJson<String>(json['campus']),
      experience: serializer.fromJson<String>(json['experience']),
      researchInterest: serializer.fromJson<String>(json['researchInterest']),
      courses: serializer.fromJson<String>(json['courses']),
      education: serializer.fromJson<String>(json['education']),
      publications: serializer.fromJson<String>(json['publications']),
      awards: serializer.fromJson<String>(json['awards']),
      workshops: serializer.fromJson<String>(json['workshops']),
      workExperience: serializer.fromJson<String>(json['workExperience']),
      memberships: serializer.fromJson<String>(json['memberships']),
      responsibilities: serializer.fromJson<String>(json['responsibilities']),
      profileUrl: serializer.fromJson<String>(json['profileUrl']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slug': serializer.toJson<String>(slug),
      'name': serializer.toJson<String>(name),
      'photoUrl': serializer.toJson<String>(photoUrl),
      'designation': serializer.toJson<String>(designation),
      'department': serializer.toJson<String>(department),
      'emailAddress': serializer.toJson<String>(emailAddress),
      'campus': serializer.toJson<String>(campus),
      'experience': serializer.toJson<String>(experience),
      'researchInterest': serializer.toJson<String>(researchInterest),
      'courses': serializer.toJson<String>(courses),
      'education': serializer.toJson<String>(education),
      'publications': serializer.toJson<String>(publications),
      'awards': serializer.toJson<String>(awards),
      'workshops': serializer.toJson<String>(workshops),
      'workExperience': serializer.toJson<String>(workExperience),
      'memberships': serializer.toJson<String>(memberships),
      'responsibilities': serializer.toJson<String>(responsibilities),
      'profileUrl': serializer.toJson<String>(profileUrl),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  FacultyCacheData copyWith(
          {String? slug,
          String? name,
          String? photoUrl,
          String? designation,
          String? department,
          String? emailAddress,
          String? campus,
          String? experience,
          String? researchInterest,
          String? courses,
          String? education,
          String? publications,
          String? awards,
          String? workshops,
          String? workExperience,
          String? memberships,
          String? responsibilities,
          String? profileUrl,
          int? cachedAt}) =>
      FacultyCacheData(
        slug: slug ?? this.slug,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        designation: designation ?? this.designation,
        department: department ?? this.department,
        emailAddress: emailAddress ?? this.emailAddress,
        campus: campus ?? this.campus,
        experience: experience ?? this.experience,
        researchInterest: researchInterest ?? this.researchInterest,
        courses: courses ?? this.courses,
        education: education ?? this.education,
        publications: publications ?? this.publications,
        awards: awards ?? this.awards,
        workshops: workshops ?? this.workshops,
        workExperience: workExperience ?? this.workExperience,
        memberships: memberships ?? this.memberships,
        responsibilities: responsibilities ?? this.responsibilities,
        profileUrl: profileUrl ?? this.profileUrl,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  FacultyCacheData copyWithCompanion(FacultyCacheCompanion data) {
    return FacultyCacheData(
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      designation:
          data.designation.present ? data.designation.value : this.designation,
      department:
          data.department.present ? data.department.value : this.department,
      emailAddress: data.emailAddress.present
          ? data.emailAddress.value
          : this.emailAddress,
      campus: data.campus.present ? data.campus.value : this.campus,
      experience:
          data.experience.present ? data.experience.value : this.experience,
      researchInterest: data.researchInterest.present
          ? data.researchInterest.value
          : this.researchInterest,
      courses: data.courses.present ? data.courses.value : this.courses,
      education: data.education.present ? data.education.value : this.education,
      publications: data.publications.present
          ? data.publications.value
          : this.publications,
      awards: data.awards.present ? data.awards.value : this.awards,
      workshops: data.workshops.present ? data.workshops.value : this.workshops,
      workExperience: data.workExperience.present
          ? data.workExperience.value
          : this.workExperience,
      memberships:
          data.memberships.present ? data.memberships.value : this.memberships,
      responsibilities: data.responsibilities.present
          ? data.responsibilities.value
          : this.responsibilities,
      profileUrl:
          data.profileUrl.present ? data.profileUrl.value : this.profileUrl,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FacultyCacheData(')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('designation: $designation, ')
          ..write('department: $department, ')
          ..write('emailAddress: $emailAddress, ')
          ..write('campus: $campus, ')
          ..write('experience: $experience, ')
          ..write('researchInterest: $researchInterest, ')
          ..write('courses: $courses, ')
          ..write('education: $education, ')
          ..write('publications: $publications, ')
          ..write('awards: $awards, ')
          ..write('workshops: $workshops, ')
          ..write('workExperience: $workExperience, ')
          ..write('memberships: $memberships, ')
          ..write('responsibilities: $responsibilities, ')
          ..write('profileUrl: $profileUrl, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      slug,
      name,
      photoUrl,
      designation,
      department,
      emailAddress,
      campus,
      experience,
      researchInterest,
      courses,
      education,
      publications,
      awards,
      workshops,
      workExperience,
      memberships,
      responsibilities,
      profileUrl,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FacultyCacheData &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.photoUrl == this.photoUrl &&
          other.designation == this.designation &&
          other.department == this.department &&
          other.emailAddress == this.emailAddress &&
          other.campus == this.campus &&
          other.experience == this.experience &&
          other.researchInterest == this.researchInterest &&
          other.courses == this.courses &&
          other.education == this.education &&
          other.publications == this.publications &&
          other.awards == this.awards &&
          other.workshops == this.workshops &&
          other.workExperience == this.workExperience &&
          other.memberships == this.memberships &&
          other.responsibilities == this.responsibilities &&
          other.profileUrl == this.profileUrl &&
          other.cachedAt == this.cachedAt);
}

class FacultyCacheCompanion extends UpdateCompanion<FacultyCacheData> {
  final Value<String> slug;
  final Value<String> name;
  final Value<String> photoUrl;
  final Value<String> designation;
  final Value<String> department;
  final Value<String> emailAddress;
  final Value<String> campus;
  final Value<String> experience;
  final Value<String> researchInterest;
  final Value<String> courses;
  final Value<String> education;
  final Value<String> publications;
  final Value<String> awards;
  final Value<String> workshops;
  final Value<String> workExperience;
  final Value<String> memberships;
  final Value<String> responsibilities;
  final Value<String> profileUrl;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const FacultyCacheCompanion({
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.designation = const Value.absent(),
    this.department = const Value.absent(),
    this.emailAddress = const Value.absent(),
    this.campus = const Value.absent(),
    this.experience = const Value.absent(),
    this.researchInterest = const Value.absent(),
    this.courses = const Value.absent(),
    this.education = const Value.absent(),
    this.publications = const Value.absent(),
    this.awards = const Value.absent(),
    this.workshops = const Value.absent(),
    this.workExperience = const Value.absent(),
    this.memberships = const Value.absent(),
    this.responsibilities = const Value.absent(),
    this.profileUrl = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FacultyCacheCompanion.insert({
    required String slug,
    this.name = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.designation = const Value.absent(),
    this.department = const Value.absent(),
    this.emailAddress = const Value.absent(),
    this.campus = const Value.absent(),
    this.experience = const Value.absent(),
    this.researchInterest = const Value.absent(),
    this.courses = const Value.absent(),
    this.education = const Value.absent(),
    this.publications = const Value.absent(),
    this.awards = const Value.absent(),
    this.workshops = const Value.absent(),
    this.workExperience = const Value.absent(),
    this.memberships = const Value.absent(),
    this.responsibilities = const Value.absent(),
    this.profileUrl = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : slug = Value(slug);
  static Insertable<FacultyCacheData> custom({
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? photoUrl,
    Expression<String>? designation,
    Expression<String>? department,
    Expression<String>? emailAddress,
    Expression<String>? campus,
    Expression<String>? experience,
    Expression<String>? researchInterest,
    Expression<String>? courses,
    Expression<String>? education,
    Expression<String>? publications,
    Expression<String>? awards,
    Expression<String>? workshops,
    Expression<String>? workExperience,
    Expression<String>? memberships,
    Expression<String>? responsibilities,
    Expression<String>? profileUrl,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (designation != null) 'designation': designation,
      if (department != null) 'department': department,
      if (emailAddress != null) 'email_address': emailAddress,
      if (campus != null) 'campus': campus,
      if (experience != null) 'experience': experience,
      if (researchInterest != null) 'research_interest': researchInterest,
      if (courses != null) 'courses': courses,
      if (education != null) 'education': education,
      if (publications != null) 'publications': publications,
      if (awards != null) 'awards': awards,
      if (workshops != null) 'workshops': workshops,
      if (workExperience != null) 'work_experience': workExperience,
      if (memberships != null) 'memberships': memberships,
      if (responsibilities != null) 'responsibilities': responsibilities,
      if (profileUrl != null) 'profile_url': profileUrl,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FacultyCacheCompanion copyWith(
      {Value<String>? slug,
      Value<String>? name,
      Value<String>? photoUrl,
      Value<String>? designation,
      Value<String>? department,
      Value<String>? emailAddress,
      Value<String>? campus,
      Value<String>? experience,
      Value<String>? researchInterest,
      Value<String>? courses,
      Value<String>? education,
      Value<String>? publications,
      Value<String>? awards,
      Value<String>? workshops,
      Value<String>? workExperience,
      Value<String>? memberships,
      Value<String>? responsibilities,
      Value<String>? profileUrl,
      Value<int>? cachedAt,
      Value<int>? rowid}) {
    return FacultyCacheCompanion(
      slug: slug ?? this.slug,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      emailAddress: emailAddress ?? this.emailAddress,
      campus: campus ?? this.campus,
      experience: experience ?? this.experience,
      researchInterest: researchInterest ?? this.researchInterest,
      courses: courses ?? this.courses,
      education: education ?? this.education,
      publications: publications ?? this.publications,
      awards: awards ?? this.awards,
      workshops: workshops ?? this.workshops,
      workExperience: workExperience ?? this.workExperience,
      memberships: memberships ?? this.memberships,
      responsibilities: responsibilities ?? this.responsibilities,
      profileUrl: profileUrl ?? this.profileUrl,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (designation.present) {
      map['designation'] = Variable<String>(designation.value);
    }
    if (department.present) {
      map['department'] = Variable<String>(department.value);
    }
    if (emailAddress.present) {
      map['email_address'] = Variable<String>(emailAddress.value);
    }
    if (campus.present) {
      map['campus'] = Variable<String>(campus.value);
    }
    if (experience.present) {
      map['experience'] = Variable<String>(experience.value);
    }
    if (researchInterest.present) {
      map['research_interest'] = Variable<String>(researchInterest.value);
    }
    if (courses.present) {
      map['courses'] = Variable<String>(courses.value);
    }
    if (education.present) {
      map['education'] = Variable<String>(education.value);
    }
    if (publications.present) {
      map['publications'] = Variable<String>(publications.value);
    }
    if (awards.present) {
      map['awards'] = Variable<String>(awards.value);
    }
    if (workshops.present) {
      map['workshops'] = Variable<String>(workshops.value);
    }
    if (workExperience.present) {
      map['work_experience'] = Variable<String>(workExperience.value);
    }
    if (memberships.present) {
      map['memberships'] = Variable<String>(memberships.value);
    }
    if (responsibilities.present) {
      map['responsibilities'] = Variable<String>(responsibilities.value);
    }
    if (profileUrl.present) {
      map['profile_url'] = Variable<String>(profileUrl.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FacultyCacheCompanion(')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('designation: $designation, ')
          ..write('department: $department, ')
          ..write('emailAddress: $emailAddress, ')
          ..write('campus: $campus, ')
          ..write('experience: $experience, ')
          ..write('researchInterest: $researchInterest, ')
          ..write('courses: $courses, ')
          ..write('education: $education, ')
          ..write('publications: $publications, ')
          ..write('awards: $awards, ')
          ..write('workshops: $workshops, ')
          ..write('workExperience: $workExperience, ')
          ..write('memberships: $memberships, ')
          ..write('responsibilities: $responsibilities, ')
          ..write('profileUrl: $profileUrl, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTableTable extends UserSettingsTable
    with TableInfo<$UserSettingsTableTable, UserSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
      'theme', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('light'));
  static const VerificationMeta _defaultViewMeta =
      const VerificationMeta('defaultView');
  @override
  late final GeneratedColumn<String> defaultView = GeneratedColumn<String>(
      'default_view', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('overview'));
  static const VerificationMeta _attendanceThresholdMeta =
      const VerificationMeta('attendanceThreshold');
  @override
  late final GeneratedColumn<double> attendanceThreshold =
      GeneratedColumn<double>('attendance_threshold', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(75.0));
  static const VerificationMeta _calendarViewMeta =
      const VerificationMeta('calendarView');
  @override
  late final GeneratedColumn<String> calendarView = GeneratedColumn<String>(
      'calendar_view', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('month'));
  static const VerificationMeta _timetableViewMeta =
      const VerificationMeta('timetableView');
  @override
  late final GeneratedColumn<String> timetableView = GeneratedColumn<String>(
      'timetable_view', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('week'));
  static const VerificationMeta _showWeekendsMeta =
      const VerificationMeta('showWeekends');
  @override
  late final GeneratedColumn<int> showWeekends = GeneratedColumn<int>(
      'show_weekends', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _biometricLockEnabledMeta =
      const VerificationMeta('biometricLockEnabled');
  @override
  late final GeneratedColumn<int> biometricLockEnabled = GeneratedColumn<int>(
      'biometric_lock_enabled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _customSpRelayUrlMeta =
      const VerificationMeta('customSpRelayUrl');
  @override
  late final GeneratedColumn<String> customSpRelayUrl = GeneratedColumn<String>(
      'custom_sp_relay_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dashboardWidgetsJsonMeta =
      const VerificationMeta('dashboardWidgetsJson');
  @override
  late final GeneratedColumn<String> dashboardWidgetsJson =
      GeneratedColumn<String>('dashboard_widgets_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _customDataJsonMeta =
      const VerificationMeta('customDataJson');
  @override
  late final GeneratedColumn<String> customDataJson = GeneratedColumn<String>(
      'custom_data_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        academiaEmail,
        theme,
        defaultView,
        attendanceThreshold,
        calendarView,
        timetableView,
        showWeekends,
        biometricLockEnabled,
        customSpRelayUrl,
        dashboardWidgetsJson,
        customDataJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<UserSettingsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('theme')) {
      context.handle(
          _themeMeta, theme.isAcceptableOrUnknown(data['theme']!, _themeMeta));
    }
    if (data.containsKey('default_view')) {
      context.handle(
          _defaultViewMeta,
          defaultView.isAcceptableOrUnknown(
              data['default_view']!, _defaultViewMeta));
    }
    if (data.containsKey('attendance_threshold')) {
      context.handle(
          _attendanceThresholdMeta,
          attendanceThreshold.isAcceptableOrUnknown(
              data['attendance_threshold']!, _attendanceThresholdMeta));
    }
    if (data.containsKey('calendar_view')) {
      context.handle(
          _calendarViewMeta,
          calendarView.isAcceptableOrUnknown(
              data['calendar_view']!, _calendarViewMeta));
    }
    if (data.containsKey('timetable_view')) {
      context.handle(
          _timetableViewMeta,
          timetableView.isAcceptableOrUnknown(
              data['timetable_view']!, _timetableViewMeta));
    }
    if (data.containsKey('show_weekends')) {
      context.handle(
          _showWeekendsMeta,
          showWeekends.isAcceptableOrUnknown(
              data['show_weekends']!, _showWeekendsMeta));
    }
    if (data.containsKey('biometric_lock_enabled')) {
      context.handle(
          _biometricLockEnabledMeta,
          biometricLockEnabled.isAcceptableOrUnknown(
              data['biometric_lock_enabled']!, _biometricLockEnabledMeta));
    }
    if (data.containsKey('custom_sp_relay_url')) {
      context.handle(
          _customSpRelayUrlMeta,
          customSpRelayUrl.isAcceptableOrUnknown(
              data['custom_sp_relay_url']!, _customSpRelayUrlMeta));
    }
    if (data.containsKey('dashboard_widgets_json')) {
      context.handle(
          _dashboardWidgetsJsonMeta,
          dashboardWidgetsJson.isAcceptableOrUnknown(
              data['dashboard_widgets_json']!, _dashboardWidgetsJsonMeta));
    }
    if (data.containsKey('custom_data_json')) {
      context.handle(
          _customDataJsonMeta,
          customDataJson.isAcceptableOrUnknown(
              data['custom_data_json']!, _customDataJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail};
  @override
  UserSettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSettingsTableData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      theme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme'])!,
      defaultView: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}default_view'])!,
      attendanceThreshold: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}attendance_threshold'])!,
      calendarView: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}calendar_view'])!,
      timetableView: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timetable_view'])!,
      showWeekends: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}show_weekends'])!,
      biometricLockEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}biometric_lock_enabled'])!,
      customSpRelayUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}custom_sp_relay_url']),
      dashboardWidgetsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}dashboard_widgets_json'])!,
      customDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}custom_data_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserSettingsTableTable createAlias(String alias) {
    return $UserSettingsTableTable(attachedDatabase, alias);
  }
}

class UserSettingsTableData extends DataClass
    implements Insertable<UserSettingsTableData> {
  final String academiaEmail;
  final String theme;
  final String defaultView;
  final double attendanceThreshold;
  final String calendarView;
  final String timetableView;
  final int showWeekends;
  final int biometricLockEnabled;
  final String? customSpRelayUrl;
  final String dashboardWidgetsJson;
  final String customDataJson;
  final int updatedAt;
  const UserSettingsTableData(
      {required this.academiaEmail,
      required this.theme,
      required this.defaultView,
      required this.attendanceThreshold,
      required this.calendarView,
      required this.timetableView,
      required this.showWeekends,
      required this.biometricLockEnabled,
      this.customSpRelayUrl,
      required this.dashboardWidgetsJson,
      required this.customDataJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['theme'] = Variable<String>(theme);
    map['default_view'] = Variable<String>(defaultView);
    map['attendance_threshold'] = Variable<double>(attendanceThreshold);
    map['calendar_view'] = Variable<String>(calendarView);
    map['timetable_view'] = Variable<String>(timetableView);
    map['show_weekends'] = Variable<int>(showWeekends);
    map['biometric_lock_enabled'] = Variable<int>(biometricLockEnabled);
    if (!nullToAbsent || customSpRelayUrl != null) {
      map['custom_sp_relay_url'] = Variable<String>(customSpRelayUrl);
    }
    map['dashboard_widgets_json'] = Variable<String>(dashboardWidgetsJson);
    map['custom_data_json'] = Variable<String>(customDataJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UserSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsTableCompanion(
      academiaEmail: Value(academiaEmail),
      theme: Value(theme),
      defaultView: Value(defaultView),
      attendanceThreshold: Value(attendanceThreshold),
      calendarView: Value(calendarView),
      timetableView: Value(timetableView),
      showWeekends: Value(showWeekends),
      biometricLockEnabled: Value(biometricLockEnabled),
      customSpRelayUrl: customSpRelayUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(customSpRelayUrl),
      dashboardWidgetsJson: Value(dashboardWidgetsJson),
      customDataJson: Value(customDataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserSettingsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSettingsTableData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      theme: serializer.fromJson<String>(json['theme']),
      defaultView: serializer.fromJson<String>(json['defaultView']),
      attendanceThreshold:
          serializer.fromJson<double>(json['attendanceThreshold']),
      calendarView: serializer.fromJson<String>(json['calendarView']),
      timetableView: serializer.fromJson<String>(json['timetableView']),
      showWeekends: serializer.fromJson<int>(json['showWeekends']),
      biometricLockEnabled:
          serializer.fromJson<int>(json['biometricLockEnabled']),
      customSpRelayUrl: serializer.fromJson<String?>(json['customSpRelayUrl']),
      dashboardWidgetsJson:
          serializer.fromJson<String>(json['dashboardWidgetsJson']),
      customDataJson: serializer.fromJson<String>(json['customDataJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'theme': serializer.toJson<String>(theme),
      'defaultView': serializer.toJson<String>(defaultView),
      'attendanceThreshold': serializer.toJson<double>(attendanceThreshold),
      'calendarView': serializer.toJson<String>(calendarView),
      'timetableView': serializer.toJson<String>(timetableView),
      'showWeekends': serializer.toJson<int>(showWeekends),
      'biometricLockEnabled': serializer.toJson<int>(biometricLockEnabled),
      'customSpRelayUrl': serializer.toJson<String?>(customSpRelayUrl),
      'dashboardWidgetsJson': serializer.toJson<String>(dashboardWidgetsJson),
      'customDataJson': serializer.toJson<String>(customDataJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UserSettingsTableData copyWith(
          {String? academiaEmail,
          String? theme,
          String? defaultView,
          double? attendanceThreshold,
          String? calendarView,
          String? timetableView,
          int? showWeekends,
          int? biometricLockEnabled,
          Value<String?> customSpRelayUrl = const Value.absent(),
          String? dashboardWidgetsJson,
          String? customDataJson,
          int? updatedAt}) =>
      UserSettingsTableData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        theme: theme ?? this.theme,
        defaultView: defaultView ?? this.defaultView,
        attendanceThreshold: attendanceThreshold ?? this.attendanceThreshold,
        calendarView: calendarView ?? this.calendarView,
        timetableView: timetableView ?? this.timetableView,
        showWeekends: showWeekends ?? this.showWeekends,
        biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
        customSpRelayUrl: customSpRelayUrl.present
            ? customSpRelayUrl.value
            : this.customSpRelayUrl,
        dashboardWidgetsJson: dashboardWidgetsJson ?? this.dashboardWidgetsJson,
        customDataJson: customDataJson ?? this.customDataJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserSettingsTableData copyWithCompanion(UserSettingsTableCompanion data) {
    return UserSettingsTableData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      theme: data.theme.present ? data.theme.value : this.theme,
      defaultView:
          data.defaultView.present ? data.defaultView.value : this.defaultView,
      attendanceThreshold: data.attendanceThreshold.present
          ? data.attendanceThreshold.value
          : this.attendanceThreshold,
      calendarView: data.calendarView.present
          ? data.calendarView.value
          : this.calendarView,
      timetableView: data.timetableView.present
          ? data.timetableView.value
          : this.timetableView,
      showWeekends: data.showWeekends.present
          ? data.showWeekends.value
          : this.showWeekends,
      biometricLockEnabled: data.biometricLockEnabled.present
          ? data.biometricLockEnabled.value
          : this.biometricLockEnabled,
      customSpRelayUrl: data.customSpRelayUrl.present
          ? data.customSpRelayUrl.value
          : this.customSpRelayUrl,
      dashboardWidgetsJson: data.dashboardWidgetsJson.present
          ? data.dashboardWidgetsJson.value
          : this.dashboardWidgetsJson,
      customDataJson: data.customDataJson.present
          ? data.customDataJson.value
          : this.customDataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsTableData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('theme: $theme, ')
          ..write('defaultView: $defaultView, ')
          ..write('attendanceThreshold: $attendanceThreshold, ')
          ..write('calendarView: $calendarView, ')
          ..write('timetableView: $timetableView, ')
          ..write('showWeekends: $showWeekends, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('customSpRelayUrl: $customSpRelayUrl, ')
          ..write('dashboardWidgetsJson: $dashboardWidgetsJson, ')
          ..write('customDataJson: $customDataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      academiaEmail,
      theme,
      defaultView,
      attendanceThreshold,
      calendarView,
      timetableView,
      showWeekends,
      biometricLockEnabled,
      customSpRelayUrl,
      dashboardWidgetsJson,
      customDataJson,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettingsTableData &&
          other.academiaEmail == this.academiaEmail &&
          other.theme == this.theme &&
          other.defaultView == this.defaultView &&
          other.attendanceThreshold == this.attendanceThreshold &&
          other.calendarView == this.calendarView &&
          other.timetableView == this.timetableView &&
          other.showWeekends == this.showWeekends &&
          other.biometricLockEnabled == this.biometricLockEnabled &&
          other.customSpRelayUrl == this.customSpRelayUrl &&
          other.dashboardWidgetsJson == this.dashboardWidgetsJson &&
          other.customDataJson == this.customDataJson &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsTableCompanion
    extends UpdateCompanion<UserSettingsTableData> {
  final Value<String> academiaEmail;
  final Value<String> theme;
  final Value<String> defaultView;
  final Value<double> attendanceThreshold;
  final Value<String> calendarView;
  final Value<String> timetableView;
  final Value<int> showWeekends;
  final Value<int> biometricLockEnabled;
  final Value<String?> customSpRelayUrl;
  final Value<String> dashboardWidgetsJson;
  final Value<String> customDataJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UserSettingsTableCompanion({
    this.academiaEmail = const Value.absent(),
    this.theme = const Value.absent(),
    this.defaultView = const Value.absent(),
    this.attendanceThreshold = const Value.absent(),
    this.calendarView = const Value.absent(),
    this.timetableView = const Value.absent(),
    this.showWeekends = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.customSpRelayUrl = const Value.absent(),
    this.dashboardWidgetsJson = const Value.absent(),
    this.customDataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsTableCompanion.insert({
    required String academiaEmail,
    this.theme = const Value.absent(),
    this.defaultView = const Value.absent(),
    this.attendanceThreshold = const Value.absent(),
    this.calendarView = const Value.absent(),
    this.timetableView = const Value.absent(),
    this.showWeekends = const Value.absent(),
    this.biometricLockEnabled = const Value.absent(),
    this.customSpRelayUrl = const Value.absent(),
    this.dashboardWidgetsJson = const Value.absent(),
    this.customDataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : academiaEmail = Value(academiaEmail);
  static Insertable<UserSettingsTableData> custom({
    Expression<String>? academiaEmail,
    Expression<String>? theme,
    Expression<String>? defaultView,
    Expression<double>? attendanceThreshold,
    Expression<String>? calendarView,
    Expression<String>? timetableView,
    Expression<int>? showWeekends,
    Expression<int>? biometricLockEnabled,
    Expression<String>? customSpRelayUrl,
    Expression<String>? dashboardWidgetsJson,
    Expression<String>? customDataJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (theme != null) 'theme': theme,
      if (defaultView != null) 'default_view': defaultView,
      if (attendanceThreshold != null)
        'attendance_threshold': attendanceThreshold,
      if (calendarView != null) 'calendar_view': calendarView,
      if (timetableView != null) 'timetable_view': timetableView,
      if (showWeekends != null) 'show_weekends': showWeekends,
      if (biometricLockEnabled != null)
        'biometric_lock_enabled': biometricLockEnabled,
      if (customSpRelayUrl != null) 'custom_sp_relay_url': customSpRelayUrl,
      if (dashboardWidgetsJson != null)
        'dashboard_widgets_json': dashboardWidgetsJson,
      if (customDataJson != null) 'custom_data_json': customDataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsTableCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<String>? theme,
      Value<String>? defaultView,
      Value<double>? attendanceThreshold,
      Value<String>? calendarView,
      Value<String>? timetableView,
      Value<int>? showWeekends,
      Value<int>? biometricLockEnabled,
      Value<String?>? customSpRelayUrl,
      Value<String>? dashboardWidgetsJson,
      Value<String>? customDataJson,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return UserSettingsTableCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      theme: theme ?? this.theme,
      defaultView: defaultView ?? this.defaultView,
      attendanceThreshold: attendanceThreshold ?? this.attendanceThreshold,
      calendarView: calendarView ?? this.calendarView,
      timetableView: timetableView ?? this.timetableView,
      showWeekends: showWeekends ?? this.showWeekends,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      customSpRelayUrl: customSpRelayUrl ?? this.customSpRelayUrl,
      dashboardWidgetsJson: dashboardWidgetsJson ?? this.dashboardWidgetsJson,
      customDataJson: customDataJson ?? this.customDataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (defaultView.present) {
      map['default_view'] = Variable<String>(defaultView.value);
    }
    if (attendanceThreshold.present) {
      map['attendance_threshold'] = Variable<double>(attendanceThreshold.value);
    }
    if (calendarView.present) {
      map['calendar_view'] = Variable<String>(calendarView.value);
    }
    if (timetableView.present) {
      map['timetable_view'] = Variable<String>(timetableView.value);
    }
    if (showWeekends.present) {
      map['show_weekends'] = Variable<int>(showWeekends.value);
    }
    if (biometricLockEnabled.present) {
      map['biometric_lock_enabled'] = Variable<int>(biometricLockEnabled.value);
    }
    if (customSpRelayUrl.present) {
      map['custom_sp_relay_url'] = Variable<String>(customSpRelayUrl.value);
    }
    if (dashboardWidgetsJson.present) {
      map['dashboard_widgets_json'] =
          Variable<String>(dashboardWidgetsJson.value);
    }
    if (customDataJson.present) {
      map['custom_data_json'] = Variable<String>(customDataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsTableCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('theme: $theme, ')
          ..write('defaultView: $defaultView, ')
          ..write('attendanceThreshold: $attendanceThreshold, ')
          ..write('calendarView: $calendarView, ')
          ..write('timetableView: $timetableView, ')
          ..write('showWeekends: $showWeekends, ')
          ..write('biometricLockEnabled: $biometricLockEnabled, ')
          ..write('customSpRelayUrl: $customSpRelayUrl, ')
          ..write('dashboardWidgetsJson: $dashboardWidgetsJson, ')
          ..write('customDataJson: $customDataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationSettingsTableTable extends NotificationSettingsTable
    with
        TableInfo<$NotificationSettingsTableTable,
            NotificationSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attendanceAlertEnabledMeta =
      const VerificationMeta('attendanceAlertEnabled');
  @override
  late final GeneratedColumn<int> attendanceAlertEnabled = GeneratedColumn<int>(
      'attendance_alert_enabled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _attendanceThresholdMeta =
      const VerificationMeta('attendanceThreshold');
  @override
  late final GeneratedColumn<double> attendanceThreshold =
      GeneratedColumn<double>('attendance_threshold', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(75.0));
  static const VerificationMeta _holidayAlertsEnabledMeta =
      const VerificationMeta('holidayAlertsEnabled');
  @override
  late final GeneratedColumn<int> holidayAlertsEnabled = GeneratedColumn<int>(
      'holiday_alerts_enabled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _pushEnabledMeta =
      const VerificationMeta('pushEnabled');
  @override
  late final GeneratedColumn<int> pushEnabled = GeneratedColumn<int>(
      'push_enabled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        academiaEmail,
        attendanceAlertEnabled,
        attendanceThreshold,
        holidayAlertsEnabled,
        pushEnabled,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_settings_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationSettingsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('attendance_alert_enabled')) {
      context.handle(
          _attendanceAlertEnabledMeta,
          attendanceAlertEnabled.isAcceptableOrUnknown(
              data['attendance_alert_enabled']!, _attendanceAlertEnabledMeta));
    }
    if (data.containsKey('attendance_threshold')) {
      context.handle(
          _attendanceThresholdMeta,
          attendanceThreshold.isAcceptableOrUnknown(
              data['attendance_threshold']!, _attendanceThresholdMeta));
    }
    if (data.containsKey('holiday_alerts_enabled')) {
      context.handle(
          _holidayAlertsEnabledMeta,
          holidayAlertsEnabled.isAcceptableOrUnknown(
              data['holiday_alerts_enabled']!, _holidayAlertsEnabledMeta));
    }
    if (data.containsKey('push_enabled')) {
      context.handle(
          _pushEnabledMeta,
          pushEnabled.isAcceptableOrUnknown(
              data['push_enabled']!, _pushEnabledMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {academiaEmail};
  @override
  NotificationSettingsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSettingsTableData(
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      attendanceAlertEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}attendance_alert_enabled'])!,
      attendanceThreshold: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}attendance_threshold'])!,
      holidayAlertsEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}holiday_alerts_enabled'])!,
      pushEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}push_enabled'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $NotificationSettingsTableTable createAlias(String alias) {
    return $NotificationSettingsTableTable(attachedDatabase, alias);
  }
}

class NotificationSettingsTableData extends DataClass
    implements Insertable<NotificationSettingsTableData> {
  final String academiaEmail;
  final int attendanceAlertEnabled;
  final double attendanceThreshold;
  final int holidayAlertsEnabled;
  final int pushEnabled;
  final int updatedAt;
  const NotificationSettingsTableData(
      {required this.academiaEmail,
      required this.attendanceAlertEnabled,
      required this.attendanceThreshold,
      required this.holidayAlertsEnabled,
      required this.pushEnabled,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['academia_email'] = Variable<String>(academiaEmail);
    map['attendance_alert_enabled'] = Variable<int>(attendanceAlertEnabled);
    map['attendance_threshold'] = Variable<double>(attendanceThreshold);
    map['holiday_alerts_enabled'] = Variable<int>(holidayAlertsEnabled);
    map['push_enabled'] = Variable<int>(pushEnabled);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  NotificationSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return NotificationSettingsTableCompanion(
      academiaEmail: Value(academiaEmail),
      attendanceAlertEnabled: Value(attendanceAlertEnabled),
      attendanceThreshold: Value(attendanceThreshold),
      holidayAlertsEnabled: Value(holidayAlertsEnabled),
      pushEnabled: Value(pushEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotificationSettingsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSettingsTableData(
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      attendanceAlertEnabled:
          serializer.fromJson<int>(json['attendanceAlertEnabled']),
      attendanceThreshold:
          serializer.fromJson<double>(json['attendanceThreshold']),
      holidayAlertsEnabled:
          serializer.fromJson<int>(json['holidayAlertsEnabled']),
      pushEnabled: serializer.fromJson<int>(json['pushEnabled']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'attendanceAlertEnabled': serializer.toJson<int>(attendanceAlertEnabled),
      'attendanceThreshold': serializer.toJson<double>(attendanceThreshold),
      'holidayAlertsEnabled': serializer.toJson<int>(holidayAlertsEnabled),
      'pushEnabled': serializer.toJson<int>(pushEnabled),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  NotificationSettingsTableData copyWith(
          {String? academiaEmail,
          int? attendanceAlertEnabled,
          double? attendanceThreshold,
          int? holidayAlertsEnabled,
          int? pushEnabled,
          int? updatedAt}) =>
      NotificationSettingsTableData(
        academiaEmail: academiaEmail ?? this.academiaEmail,
        attendanceAlertEnabled:
            attendanceAlertEnabled ?? this.attendanceAlertEnabled,
        attendanceThreshold: attendanceThreshold ?? this.attendanceThreshold,
        holidayAlertsEnabled: holidayAlertsEnabled ?? this.holidayAlertsEnabled,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  NotificationSettingsTableData copyWithCompanion(
      NotificationSettingsTableCompanion data) {
    return NotificationSettingsTableData(
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      attendanceAlertEnabled: data.attendanceAlertEnabled.present
          ? data.attendanceAlertEnabled.value
          : this.attendanceAlertEnabled,
      attendanceThreshold: data.attendanceThreshold.present
          ? data.attendanceThreshold.value
          : this.attendanceThreshold,
      holidayAlertsEnabled: data.holidayAlertsEnabled.present
          ? data.holidayAlertsEnabled.value
          : this.holidayAlertsEnabled,
      pushEnabled:
          data.pushEnabled.present ? data.pushEnabled.value : this.pushEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSettingsTableData(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('attendanceAlertEnabled: $attendanceAlertEnabled, ')
          ..write('attendanceThreshold: $attendanceThreshold, ')
          ..write('holidayAlertsEnabled: $holidayAlertsEnabled, ')
          ..write('pushEnabled: $pushEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(academiaEmail, attendanceAlertEnabled,
      attendanceThreshold, holidayAlertsEnabled, pushEnabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSettingsTableData &&
          other.academiaEmail == this.academiaEmail &&
          other.attendanceAlertEnabled == this.attendanceAlertEnabled &&
          other.attendanceThreshold == this.attendanceThreshold &&
          other.holidayAlertsEnabled == this.holidayAlertsEnabled &&
          other.pushEnabled == this.pushEnabled &&
          other.updatedAt == this.updatedAt);
}

class NotificationSettingsTableCompanion
    extends UpdateCompanion<NotificationSettingsTableData> {
  final Value<String> academiaEmail;
  final Value<int> attendanceAlertEnabled;
  final Value<double> attendanceThreshold;
  final Value<int> holidayAlertsEnabled;
  final Value<int> pushEnabled;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const NotificationSettingsTableCompanion({
    this.academiaEmail = const Value.absent(),
    this.attendanceAlertEnabled = const Value.absent(),
    this.attendanceThreshold = const Value.absent(),
    this.holidayAlertsEnabled = const Value.absent(),
    this.pushEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationSettingsTableCompanion.insert({
    required String academiaEmail,
    this.attendanceAlertEnabled = const Value.absent(),
    this.attendanceThreshold = const Value.absent(),
    this.holidayAlertsEnabled = const Value.absent(),
    this.pushEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : academiaEmail = Value(academiaEmail);
  static Insertable<NotificationSettingsTableData> custom({
    Expression<String>? academiaEmail,
    Expression<int>? attendanceAlertEnabled,
    Expression<double>? attendanceThreshold,
    Expression<int>? holidayAlertsEnabled,
    Expression<int>? pushEnabled,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (attendanceAlertEnabled != null)
        'attendance_alert_enabled': attendanceAlertEnabled,
      if (attendanceThreshold != null)
        'attendance_threshold': attendanceThreshold,
      if (holidayAlertsEnabled != null)
        'holiday_alerts_enabled': holidayAlertsEnabled,
      if (pushEnabled != null) 'push_enabled': pushEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationSettingsTableCompanion copyWith(
      {Value<String>? academiaEmail,
      Value<int>? attendanceAlertEnabled,
      Value<double>? attendanceThreshold,
      Value<int>? holidayAlertsEnabled,
      Value<int>? pushEnabled,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return NotificationSettingsTableCompanion(
      academiaEmail: academiaEmail ?? this.academiaEmail,
      attendanceAlertEnabled:
          attendanceAlertEnabled ?? this.attendanceAlertEnabled,
      attendanceThreshold: attendanceThreshold ?? this.attendanceThreshold,
      holidayAlertsEnabled: holidayAlertsEnabled ?? this.holidayAlertsEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (attendanceAlertEnabled.present) {
      map['attendance_alert_enabled'] =
          Variable<int>(attendanceAlertEnabled.value);
    }
    if (attendanceThreshold.present) {
      map['attendance_threshold'] = Variable<double>(attendanceThreshold.value);
    }
    if (holidayAlertsEnabled.present) {
      map['holiday_alerts_enabled'] = Variable<int>(holidayAlertsEnabled.value);
    }
    if (pushEnabled.present) {
      map['push_enabled'] = Variable<int>(pushEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSettingsTableCompanion(')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('attendanceAlertEnabled: $attendanceAlertEnabled, ')
          ..write('attendanceThreshold: $attendanceThreshold, ')
          ..write('holidayAlertsEnabled: $holidayAlertsEnabled, ')
          ..write('pushEnabled: $pushEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTableTable extends NotificationsTable
    with TableInfo<$NotificationsTableTable, NotificationsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _academiaEmailMeta =
      const VerificationMeta('academiaEmail');
  @override
  late final GeneratedColumn<String> academiaEmail = GeneratedColumn<String>(
      'academia_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataJsonMeta =
      const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
      'data_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<int> read = GeneratedColumn<int>(
      'read', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, academiaEmail, type, title, body, dataJson, read, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('academia_email')) {
      context.handle(
          _academiaEmailMeta,
          academiaEmail.isAcceptableOrUnknown(
              data['academia_email']!, _academiaEmailMeta));
    } else if (isInserting) {
      context.missing(_academiaEmailMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(_dataJsonMeta,
          dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta));
    }
    if (data.containsKey('read')) {
      context.handle(
          _readMeta, read.isAcceptableOrUnknown(data['read']!, _readMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      academiaEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academia_email'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      dataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_json'])!,
      read: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}read'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NotificationsTableTable createAlias(String alias) {
    return $NotificationsTableTable(attachedDatabase, alias);
  }
}

class NotificationsTableData extends DataClass
    implements Insertable<NotificationsTableData> {
  final String id;
  final String academiaEmail;
  final String type;
  final String title;
  final String body;
  final String dataJson;
  final int read;
  final int createdAt;
  const NotificationsTableData(
      {required this.id,
      required this.academiaEmail,
      required this.type,
      required this.title,
      required this.body,
      required this.dataJson,
      required this.read,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['academia_email'] = Variable<String>(academiaEmail);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['data_json'] = Variable<String>(dataJson);
    map['read'] = Variable<int>(read);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  NotificationsTableCompanion toCompanion(bool nullToAbsent) {
    return NotificationsTableCompanion(
      id: Value(id),
      academiaEmail: Value(academiaEmail),
      type: Value(type),
      title: Value(title),
      body: Value(body),
      dataJson: Value(dataJson),
      read: Value(read),
      createdAt: Value(createdAt),
    );
  }

  factory NotificationsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationsTableData(
      id: serializer.fromJson<String>(json['id']),
      academiaEmail: serializer.fromJson<String>(json['academiaEmail']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      read: serializer.fromJson<int>(json['read']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'academiaEmail': serializer.toJson<String>(academiaEmail),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'dataJson': serializer.toJson<String>(dataJson),
      'read': serializer.toJson<int>(read),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  NotificationsTableData copyWith(
          {String? id,
          String? academiaEmail,
          String? type,
          String? title,
          String? body,
          String? dataJson,
          int? read,
          int? createdAt}) =>
      NotificationsTableData(
        id: id ?? this.id,
        academiaEmail: academiaEmail ?? this.academiaEmail,
        type: type ?? this.type,
        title: title ?? this.title,
        body: body ?? this.body,
        dataJson: dataJson ?? this.dataJson,
        read: read ?? this.read,
        createdAt: createdAt ?? this.createdAt,
      );
  NotificationsTableData copyWithCompanion(NotificationsTableCompanion data) {
    return NotificationsTableData(
      id: data.id.present ? data.id.value : this.id,
      academiaEmail: data.academiaEmail.present
          ? data.academiaEmail.value
          : this.academiaEmail,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      read: data.read.present ? data.read.value : this.read,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsTableData(')
          ..write('id: $id, ')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('dataJson: $dataJson, ')
          ..write('read: $read, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, academiaEmail, type, title, body, dataJson, read, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationsTableData &&
          other.id == this.id &&
          other.academiaEmail == this.academiaEmail &&
          other.type == this.type &&
          other.title == this.title &&
          other.body == this.body &&
          other.dataJson == this.dataJson &&
          other.read == this.read &&
          other.createdAt == this.createdAt);
}

class NotificationsTableCompanion
    extends UpdateCompanion<NotificationsTableData> {
  final Value<String> id;
  final Value<String> academiaEmail;
  final Value<String> type;
  final Value<String> title;
  final Value<String> body;
  final Value<String> dataJson;
  final Value<int> read;
  final Value<int> createdAt;
  final Value<int> rowid;
  const NotificationsTableCompanion({
    this.id = const Value.absent(),
    this.academiaEmail = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.read = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsTableCompanion.insert({
    required String id,
    required String academiaEmail,
    required String type,
    required String title,
    required String body,
    this.dataJson = const Value.absent(),
    this.read = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        academiaEmail = Value(academiaEmail),
        type = Value(type),
        title = Value(title),
        body = Value(body);
  static Insertable<NotificationsTableData> custom({
    Expression<String>? id,
    Expression<String>? academiaEmail,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? dataJson,
    Expression<int>? read,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academiaEmail != null) 'academia_email': academiaEmail,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (dataJson != null) 'data_json': dataJson,
      if (read != null) 'read': read,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? academiaEmail,
      Value<String>? type,
      Value<String>? title,
      Value<String>? body,
      Value<String>? dataJson,
      Value<int>? read,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return NotificationsTableCompanion(
      id: id ?? this.id,
      academiaEmail: academiaEmail ?? this.academiaEmail,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      dataJson: dataJson ?? this.dataJson,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (academiaEmail.present) {
      map['academia_email'] = Variable<String>(academiaEmail.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (read.present) {
      map['read'] = Variable<int>(read.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsTableCompanion(')
          ..write('id: $id, ')
          ..write('academiaEmail: $academiaEmail, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('dataJson: $dataJson, ')
          ..write('read: $read, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StudentProfilesTable studentProfiles =
      $StudentProfilesTable(this);
  late final $AttendanceCacheTable attendanceCache =
      $AttendanceCacheTable(this);
  late final $AttendanceSnapshotsTable attendanceSnapshots =
      $AttendanceSnapshotsTable(this);
  late final $TimetableCacheTable timetableCache = $TimetableCacheTable(this);
  late final $MarksCacheTable marksCache = $MarksCacheTable(this);
  late final $CalendarCacheTable calendarCache = $CalendarCacheTable(this);
  late final $FacultyCacheTable facultyCache = $FacultyCacheTable(this);
  late final $UserSettingsTableTable userSettingsTable =
      $UserSettingsTableTable(this);
  late final $NotificationSettingsTableTable notificationSettingsTable =
      $NotificationSettingsTableTable(this);
  late final $NotificationsTableTable notificationsTable =
      $NotificationsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        studentProfiles,
        attendanceCache,
        attendanceSnapshots,
        timetableCache,
        marksCache,
        calendarCache,
        facultyCache,
        userSettingsTable,
        notificationSettingsTable,
        notificationsTable
      ];
}

typedef $$StudentProfilesTableCreateCompanionBuilder = StudentProfilesCompanion
    Function({
  required String academiaEmail,
  required String name,
  Value<String> regNumber,
  Value<String> photoUrl,
  Value<double> cgpa,
  Value<String> branch,
  Value<String> section,
  Value<String> semester,
  Value<String> batch,
  Value<String> phone,
  Value<String> email,
  Value<String> parentEmail,
  Value<String> parentPhone,
  Value<String> mentor,
  Value<String> program,
  Value<String> campus,
  Value<String> rawDataJson,
  Value<int> cachedAt,
  Value<int> rowid,
});
typedef $$StudentProfilesTableUpdateCompanionBuilder = StudentProfilesCompanion
    Function({
  Value<String> academiaEmail,
  Value<String> name,
  Value<String> regNumber,
  Value<String> photoUrl,
  Value<double> cgpa,
  Value<String> branch,
  Value<String> section,
  Value<String> semester,
  Value<String> batch,
  Value<String> phone,
  Value<String> email,
  Value<String> parentEmail,
  Value<String> parentPhone,
  Value<String> mentor,
  Value<String> program,
  Value<String> campus,
  Value<String> rawDataJson,
  Value<int> cachedAt,
  Value<int> rowid,
});

class $$StudentProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $StudentProfilesTable> {
  $$StudentProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get regNumber => $composableBuilder(
      column: $table.regNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cgpa => $composableBuilder(
      column: $table.cgpa, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get section => $composableBuilder(
      column: $table.section, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batch => $composableBuilder(
      column: $table.batch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentEmail => $composableBuilder(
      column: $table.parentEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentPhone => $composableBuilder(
      column: $table.parentPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mentor => $composableBuilder(
      column: $table.mentor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get program => $composableBuilder(
      column: $table.program, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$StudentProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentProfilesTable> {
  $$StudentProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get regNumber => $composableBuilder(
      column: $table.regNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cgpa => $composableBuilder(
      column: $table.cgpa, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get section => $composableBuilder(
      column: $table.section, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batch => $composableBuilder(
      column: $table.batch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentEmail => $composableBuilder(
      column: $table.parentEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentPhone => $composableBuilder(
      column: $table.parentPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mentor => $composableBuilder(
      column: $table.mentor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get program => $composableBuilder(
      column: $table.program, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$StudentProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentProfilesTable> {
  $$StudentProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get regNumber =>
      $composableBuilder(column: $table.regNumber, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<double> get cgpa =>
      $composableBuilder(column: $table.cgpa, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get batch =>
      $composableBuilder(column: $table.batch, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get parentEmail => $composableBuilder(
      column: $table.parentEmail, builder: (column) => column);

  GeneratedColumn<String> get parentPhone => $composableBuilder(
      column: $table.parentPhone, builder: (column) => column);

  GeneratedColumn<String> get mentor =>
      $composableBuilder(column: $table.mentor, builder: (column) => column);

  GeneratedColumn<String> get program =>
      $composableBuilder(column: $table.program, builder: (column) => column);

  GeneratedColumn<String> get campus =>
      $composableBuilder(column: $table.campus, builder: (column) => column);

  GeneratedColumn<String> get rawDataJson => $composableBuilder(
      column: $table.rawDataJson, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$StudentProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StudentProfilesTable,
    StudentProfile,
    $$StudentProfilesTableFilterComposer,
    $$StudentProfilesTableOrderingComposer,
    $$StudentProfilesTableAnnotationComposer,
    $$StudentProfilesTableCreateCompanionBuilder,
    $$StudentProfilesTableUpdateCompanionBuilder,
    (
      StudentProfile,
      BaseReferences<_$AppDatabase, $StudentProfilesTable, StudentProfile>
    ),
    StudentProfile,
    PrefetchHooks Function()> {
  $$StudentProfilesTableTableManager(
      _$AppDatabase db, $StudentProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> regNumber = const Value.absent(),
            Value<String> photoUrl = const Value.absent(),
            Value<double> cgpa = const Value.absent(),
            Value<String> branch = const Value.absent(),
            Value<String> section = const Value.absent(),
            Value<String> semester = const Value.absent(),
            Value<String> batch = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> parentEmail = const Value.absent(),
            Value<String> parentPhone = const Value.absent(),
            Value<String> mentor = const Value.absent(),
            Value<String> program = const Value.absent(),
            Value<String> campus = const Value.absent(),
            Value<String> rawDataJson = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudentProfilesCompanion(
            academiaEmail: academiaEmail,
            name: name,
            regNumber: regNumber,
            photoUrl: photoUrl,
            cgpa: cgpa,
            branch: branch,
            section: section,
            semester: semester,
            batch: batch,
            phone: phone,
            email: email,
            parentEmail: parentEmail,
            parentPhone: parentPhone,
            mentor: mentor,
            program: program,
            campus: campus,
            rawDataJson: rawDataJson,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            required String name,
            Value<String> regNumber = const Value.absent(),
            Value<String> photoUrl = const Value.absent(),
            Value<double> cgpa = const Value.absent(),
            Value<String> branch = const Value.absent(),
            Value<String> section = const Value.absent(),
            Value<String> semester = const Value.absent(),
            Value<String> batch = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> parentEmail = const Value.absent(),
            Value<String> parentPhone = const Value.absent(),
            Value<String> mentor = const Value.absent(),
            Value<String> program = const Value.absent(),
            Value<String> campus = const Value.absent(),
            Value<String> rawDataJson = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudentProfilesCompanion.insert(
            academiaEmail: academiaEmail,
            name: name,
            regNumber: regNumber,
            photoUrl: photoUrl,
            cgpa: cgpa,
            branch: branch,
            section: section,
            semester: semester,
            batch: batch,
            phone: phone,
            email: email,
            parentEmail: parentEmail,
            parentPhone: parentPhone,
            mentor: mentor,
            program: program,
            campus: campus,
            rawDataJson: rawDataJson,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StudentProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StudentProfilesTable,
    StudentProfile,
    $$StudentProfilesTableFilterComposer,
    $$StudentProfilesTableOrderingComposer,
    $$StudentProfilesTableAnnotationComposer,
    $$StudentProfilesTableCreateCompanionBuilder,
    $$StudentProfilesTableUpdateCompanionBuilder,
    (
      StudentProfile,
      BaseReferences<_$AppDatabase, $StudentProfilesTable, StudentProfile>
    ),
    StudentProfile,
    PrefetchHooks Function()>;
typedef $$AttendanceCacheTableCreateCompanionBuilder = AttendanceCacheCompanion
    Function({
  required String academiaEmail,
  required String courseCode,
  Value<String> courseTitle,
  Value<String> category,
  Value<String> facultyName,
  Value<String> slot,
  Value<String> roomNo,
  Value<int> hoursConducted,
  Value<int> hoursAbsent,
  Value<double> attendancePct,
  Value<String> source,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$AttendanceCacheTableUpdateCompanionBuilder = AttendanceCacheCompanion
    Function({
  Value<String> academiaEmail,
  Value<String> courseCode,
  Value<String> courseTitle,
  Value<String> category,
  Value<String> facultyName,
  Value<String> slot,
  Value<String> roomNo,
  Value<int> hoursConducted,
  Value<int> hoursAbsent,
  Value<double> attendancePct,
  Value<String> source,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$AttendanceCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceCacheTable> {
  $$AttendanceCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get facultyName => $composableBuilder(
      column: $table.facultyName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slot => $composableBuilder(
      column: $table.slot, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomNo => $composableBuilder(
      column: $table.roomNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hoursConducted => $composableBuilder(
      column: $table.hoursConducted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hoursAbsent => $composableBuilder(
      column: $table.hoursAbsent, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get attendancePct => $composableBuilder(
      column: $table.attendancePct, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AttendanceCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceCacheTable> {
  $$AttendanceCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get facultyName => $composableBuilder(
      column: $table.facultyName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slot => $composableBuilder(
      column: $table.slot, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomNo => $composableBuilder(
      column: $table.roomNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hoursConducted => $composableBuilder(
      column: $table.hoursConducted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hoursAbsent => $composableBuilder(
      column: $table.hoursAbsent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get attendancePct => $composableBuilder(
      column: $table.attendancePct,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AttendanceCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceCacheTable> {
  $$AttendanceCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => column);

  GeneratedColumn<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get facultyName => $composableBuilder(
      column: $table.facultyName, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get roomNo =>
      $composableBuilder(column: $table.roomNo, builder: (column) => column);

  GeneratedColumn<int> get hoursConducted => $composableBuilder(
      column: $table.hoursConducted, builder: (column) => column);

  GeneratedColumn<int> get hoursAbsent => $composableBuilder(
      column: $table.hoursAbsent, builder: (column) => column);

  GeneratedColumn<double> get attendancePct => $composableBuilder(
      column: $table.attendancePct, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AttendanceCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttendanceCacheTable,
    AttendanceCacheData,
    $$AttendanceCacheTableFilterComposer,
    $$AttendanceCacheTableOrderingComposer,
    $$AttendanceCacheTableAnnotationComposer,
    $$AttendanceCacheTableCreateCompanionBuilder,
    $$AttendanceCacheTableUpdateCompanionBuilder,
    (
      AttendanceCacheData,
      BaseReferences<_$AppDatabase, $AttendanceCacheTable, AttendanceCacheData>
    ),
    AttendanceCacheData,
    PrefetchHooks Function()> {
  $$AttendanceCacheTableTableManager(
      _$AppDatabase db, $AttendanceCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> courseCode = const Value.absent(),
            Value<String> courseTitle = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> facultyName = const Value.absent(),
            Value<String> slot = const Value.absent(),
            Value<String> roomNo = const Value.absent(),
            Value<int> hoursConducted = const Value.absent(),
            Value<int> hoursAbsent = const Value.absent(),
            Value<double> attendancePct = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttendanceCacheCompanion(
            academiaEmail: academiaEmail,
            courseCode: courseCode,
            courseTitle: courseTitle,
            category: category,
            facultyName: facultyName,
            slot: slot,
            roomNo: roomNo,
            hoursConducted: hoursConducted,
            hoursAbsent: hoursAbsent,
            attendancePct: attendancePct,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            required String courseCode,
            Value<String> courseTitle = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> facultyName = const Value.absent(),
            Value<String> slot = const Value.absent(),
            Value<String> roomNo = const Value.absent(),
            Value<int> hoursConducted = const Value.absent(),
            Value<int> hoursAbsent = const Value.absent(),
            Value<double> attendancePct = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttendanceCacheCompanion.insert(
            academiaEmail: academiaEmail,
            courseCode: courseCode,
            courseTitle: courseTitle,
            category: category,
            facultyName: facultyName,
            slot: slot,
            roomNo: roomNo,
            hoursConducted: hoursConducted,
            hoursAbsent: hoursAbsent,
            attendancePct: attendancePct,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AttendanceCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttendanceCacheTable,
    AttendanceCacheData,
    $$AttendanceCacheTableFilterComposer,
    $$AttendanceCacheTableOrderingComposer,
    $$AttendanceCacheTableAnnotationComposer,
    $$AttendanceCacheTableCreateCompanionBuilder,
    $$AttendanceCacheTableUpdateCompanionBuilder,
    (
      AttendanceCacheData,
      BaseReferences<_$AppDatabase, $AttendanceCacheTable, AttendanceCacheData>
    ),
    AttendanceCacheData,
    PrefetchHooks Function()>;
typedef $$AttendanceSnapshotsTableCreateCompanionBuilder
    = AttendanceSnapshotsCompanion Function({
  Value<int> id,
  required String academiaEmail,
  required String snapshotDate,
  Value<double> overallPercentage,
  Value<double> weightedPercentage,
  Value<String> subjectsJson,
  Value<int> totalClasses,
  Value<int> attendedClasses,
  Value<int> createdAt,
});
typedef $$AttendanceSnapshotsTableUpdateCompanionBuilder
    = AttendanceSnapshotsCompanion Function({
  Value<int> id,
  Value<String> academiaEmail,
  Value<String> snapshotDate,
  Value<double> overallPercentage,
  Value<double> weightedPercentage,
  Value<String> subjectsJson,
  Value<int> totalClasses,
  Value<int> attendedClasses,
  Value<int> createdAt,
});

class $$AttendanceSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceSnapshotsTable> {
  $$AttendanceSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get overallPercentage => $composableBuilder(
      column: $table.overallPercentage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightedPercentage => $composableBuilder(
      column: $table.weightedPercentage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectsJson => $composableBuilder(
      column: $table.subjectsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalClasses => $composableBuilder(
      column: $table.totalClasses, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attendedClasses => $composableBuilder(
      column: $table.attendedClasses,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AttendanceSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceSnapshotsTable> {
  $$AttendanceSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get overallPercentage => $composableBuilder(
      column: $table.overallPercentage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightedPercentage => $composableBuilder(
      column: $table.weightedPercentage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectsJson => $composableBuilder(
      column: $table.subjectsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalClasses => $composableBuilder(
      column: $table.totalClasses,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attendedClasses => $composableBuilder(
      column: $table.attendedClasses,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AttendanceSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceSnapshotsTable> {
  $$AttendanceSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get snapshotDate => $composableBuilder(
      column: $table.snapshotDate, builder: (column) => column);

  GeneratedColumn<double> get overallPercentage => $composableBuilder(
      column: $table.overallPercentage, builder: (column) => column);

  GeneratedColumn<double> get weightedPercentage => $composableBuilder(
      column: $table.weightedPercentage, builder: (column) => column);

  GeneratedColumn<String> get subjectsJson => $composableBuilder(
      column: $table.subjectsJson, builder: (column) => column);

  GeneratedColumn<int> get totalClasses => $composableBuilder(
      column: $table.totalClasses, builder: (column) => column);

  GeneratedColumn<int> get attendedClasses => $composableBuilder(
      column: $table.attendedClasses, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttendanceSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttendanceSnapshotsTable,
    AttendanceSnapshot,
    $$AttendanceSnapshotsTableFilterComposer,
    $$AttendanceSnapshotsTableOrderingComposer,
    $$AttendanceSnapshotsTableAnnotationComposer,
    $$AttendanceSnapshotsTableCreateCompanionBuilder,
    $$AttendanceSnapshotsTableUpdateCompanionBuilder,
    (
      AttendanceSnapshot,
      BaseReferences<_$AppDatabase, $AttendanceSnapshotsTable,
          AttendanceSnapshot>
    ),
    AttendanceSnapshot,
    PrefetchHooks Function()> {
  $$AttendanceSnapshotsTableTableManager(
      _$AppDatabase db, $AttendanceSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceSnapshotsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceSnapshotsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> academiaEmail = const Value.absent(),
            Value<String> snapshotDate = const Value.absent(),
            Value<double> overallPercentage = const Value.absent(),
            Value<double> weightedPercentage = const Value.absent(),
            Value<String> subjectsJson = const Value.absent(),
            Value<int> totalClasses = const Value.absent(),
            Value<int> attendedClasses = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              AttendanceSnapshotsCompanion(
            id: id,
            academiaEmail: academiaEmail,
            snapshotDate: snapshotDate,
            overallPercentage: overallPercentage,
            weightedPercentage: weightedPercentage,
            subjectsJson: subjectsJson,
            totalClasses: totalClasses,
            attendedClasses: attendedClasses,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String academiaEmail,
            required String snapshotDate,
            Value<double> overallPercentage = const Value.absent(),
            Value<double> weightedPercentage = const Value.absent(),
            Value<String> subjectsJson = const Value.absent(),
            Value<int> totalClasses = const Value.absent(),
            Value<int> attendedClasses = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              AttendanceSnapshotsCompanion.insert(
            id: id,
            academiaEmail: academiaEmail,
            snapshotDate: snapshotDate,
            overallPercentage: overallPercentage,
            weightedPercentage: weightedPercentage,
            subjectsJson: subjectsJson,
            totalClasses: totalClasses,
            attendedClasses: attendedClasses,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AttendanceSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttendanceSnapshotsTable,
    AttendanceSnapshot,
    $$AttendanceSnapshotsTableFilterComposer,
    $$AttendanceSnapshotsTableOrderingComposer,
    $$AttendanceSnapshotsTableAnnotationComposer,
    $$AttendanceSnapshotsTableCreateCompanionBuilder,
    $$AttendanceSnapshotsTableUpdateCompanionBuilder,
    (
      AttendanceSnapshot,
      BaseReferences<_$AppDatabase, $AttendanceSnapshotsTable,
          AttendanceSnapshot>
    ),
    AttendanceSnapshot,
    PrefetchHooks Function()>;
typedef $$TimetableCacheTableCreateCompanionBuilder = TimetableCacheCompanion
    Function({
  required String academiaEmail,
  Value<String> batch,
  Value<String> coursesJson,
  Value<String> advisorsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$TimetableCacheTableUpdateCompanionBuilder = TimetableCacheCompanion
    Function({
  Value<String> academiaEmail,
  Value<String> batch,
  Value<String> coursesJson,
  Value<String> advisorsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$TimetableCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TimetableCacheTable> {
  $$TimetableCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batch => $composableBuilder(
      column: $table.batch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coursesJson => $composableBuilder(
      column: $table.coursesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get advisorsJson => $composableBuilder(
      column: $table.advisorsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TimetableCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TimetableCacheTable> {
  $$TimetableCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batch => $composableBuilder(
      column: $table.batch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coursesJson => $composableBuilder(
      column: $table.coursesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get advisorsJson => $composableBuilder(
      column: $table.advisorsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TimetableCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimetableCacheTable> {
  $$TimetableCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get batch =>
      $composableBuilder(column: $table.batch, builder: (column) => column);

  GeneratedColumn<String> get coursesJson => $composableBuilder(
      column: $table.coursesJson, builder: (column) => column);

  GeneratedColumn<String> get advisorsJson => $composableBuilder(
      column: $table.advisorsJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TimetableCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TimetableCacheTable,
    TimetableCacheData,
    $$TimetableCacheTableFilterComposer,
    $$TimetableCacheTableOrderingComposer,
    $$TimetableCacheTableAnnotationComposer,
    $$TimetableCacheTableCreateCompanionBuilder,
    $$TimetableCacheTableUpdateCompanionBuilder,
    (
      TimetableCacheData,
      BaseReferences<_$AppDatabase, $TimetableCacheTable, TimetableCacheData>
    ),
    TimetableCacheData,
    PrefetchHooks Function()> {
  $$TimetableCacheTableTableManager(
      _$AppDatabase db, $TimetableCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimetableCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimetableCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimetableCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> batch = const Value.absent(),
            Value<String> coursesJson = const Value.absent(),
            Value<String> advisorsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TimetableCacheCompanion(
            academiaEmail: academiaEmail,
            batch: batch,
            coursesJson: coursesJson,
            advisorsJson: advisorsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            Value<String> batch = const Value.absent(),
            Value<String> coursesJson = const Value.absent(),
            Value<String> advisorsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TimetableCacheCompanion.insert(
            academiaEmail: academiaEmail,
            batch: batch,
            coursesJson: coursesJson,
            advisorsJson: advisorsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TimetableCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TimetableCacheTable,
    TimetableCacheData,
    $$TimetableCacheTableFilterComposer,
    $$TimetableCacheTableOrderingComposer,
    $$TimetableCacheTableAnnotationComposer,
    $$TimetableCacheTableCreateCompanionBuilder,
    $$TimetableCacheTableUpdateCompanionBuilder,
    (
      TimetableCacheData,
      BaseReferences<_$AppDatabase, $TimetableCacheTable, TimetableCacheData>
    ),
    TimetableCacheData,
    PrefetchHooks Function()>;
typedef $$MarksCacheTableCreateCompanionBuilder = MarksCacheCompanion Function({
  required String academiaEmail,
  required String courseCode,
  Value<String> courseTitle,
  Value<String> courseType,
  Value<String> source,
  Value<String> testsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$MarksCacheTableUpdateCompanionBuilder = MarksCacheCompanion Function({
  Value<String> academiaEmail,
  Value<String> courseCode,
  Value<String> courseTitle,
  Value<String> courseType,
  Value<String> source,
  Value<String> testsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$MarksCacheTableFilterComposer
    extends Composer<_$AppDatabase, $MarksCacheTable> {
  $$MarksCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseType => $composableBuilder(
      column: $table.courseType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get testsJson => $composableBuilder(
      column: $table.testsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MarksCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $MarksCacheTable> {
  $$MarksCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseType => $composableBuilder(
      column: $table.courseType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get testsJson => $composableBuilder(
      column: $table.testsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MarksCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarksCacheTable> {
  $$MarksCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => column);

  GeneratedColumn<String> get courseTitle => $composableBuilder(
      column: $table.courseTitle, builder: (column) => column);

  GeneratedColumn<String> get courseType => $composableBuilder(
      column: $table.courseType, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get testsJson =>
      $composableBuilder(column: $table.testsJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MarksCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MarksCacheTable,
    MarksCacheData,
    $$MarksCacheTableFilterComposer,
    $$MarksCacheTableOrderingComposer,
    $$MarksCacheTableAnnotationComposer,
    $$MarksCacheTableCreateCompanionBuilder,
    $$MarksCacheTableUpdateCompanionBuilder,
    (
      MarksCacheData,
      BaseReferences<_$AppDatabase, $MarksCacheTable, MarksCacheData>
    ),
    MarksCacheData,
    PrefetchHooks Function()> {
  $$MarksCacheTableTableManager(_$AppDatabase db, $MarksCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarksCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarksCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarksCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> courseCode = const Value.absent(),
            Value<String> courseTitle = const Value.absent(),
            Value<String> courseType = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> testsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MarksCacheCompanion(
            academiaEmail: academiaEmail,
            courseCode: courseCode,
            courseTitle: courseTitle,
            courseType: courseType,
            source: source,
            testsJson: testsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            required String courseCode,
            Value<String> courseTitle = const Value.absent(),
            Value<String> courseType = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> testsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MarksCacheCompanion.insert(
            academiaEmail: academiaEmail,
            courseCode: courseCode,
            courseTitle: courseTitle,
            courseType: courseType,
            source: source,
            testsJson: testsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MarksCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MarksCacheTable,
    MarksCacheData,
    $$MarksCacheTableFilterComposer,
    $$MarksCacheTableOrderingComposer,
    $$MarksCacheTableAnnotationComposer,
    $$MarksCacheTableCreateCompanionBuilder,
    $$MarksCacheTableUpdateCompanionBuilder,
    (
      MarksCacheData,
      BaseReferences<_$AppDatabase, $MarksCacheTable, MarksCacheData>
    ),
    MarksCacheData,
    PrefetchHooks Function()>;
typedef $$CalendarCacheTableCreateCompanionBuilder = CalendarCacheCompanion
    Function({
  required String academiaEmail,
  required String semester,
  Value<String> title,
  Value<String> monthsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$CalendarCacheTableUpdateCompanionBuilder = CalendarCacheCompanion
    Function({
  Value<String> academiaEmail,
  Value<String> semester,
  Value<String> title,
  Value<String> monthsJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$CalendarCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get monthsJson => $composableBuilder(
      column: $table.monthsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CalendarCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get monthsJson => $composableBuilder(
      column: $table.monthsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CalendarCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarCacheTable> {
  $$CalendarCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get monthsJson => $composableBuilder(
      column: $table.monthsJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CalendarCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalendarCacheTable,
    CalendarCacheData,
    $$CalendarCacheTableFilterComposer,
    $$CalendarCacheTableOrderingComposer,
    $$CalendarCacheTableAnnotationComposer,
    $$CalendarCacheTableCreateCompanionBuilder,
    $$CalendarCacheTableUpdateCompanionBuilder,
    (
      CalendarCacheData,
      BaseReferences<_$AppDatabase, $CalendarCacheTable, CalendarCacheData>
    ),
    CalendarCacheData,
    PrefetchHooks Function()> {
  $$CalendarCacheTableTableManager(_$AppDatabase db, $CalendarCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> semester = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> monthsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarCacheCompanion(
            academiaEmail: academiaEmail,
            semester: semester,
            title: title,
            monthsJson: monthsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            required String semester,
            Value<String> title = const Value.absent(),
            Value<String> monthsJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarCacheCompanion.insert(
            academiaEmail: academiaEmail,
            semester: semester,
            title: title,
            monthsJson: monthsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalendarCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalendarCacheTable,
    CalendarCacheData,
    $$CalendarCacheTableFilterComposer,
    $$CalendarCacheTableOrderingComposer,
    $$CalendarCacheTableAnnotationComposer,
    $$CalendarCacheTableCreateCompanionBuilder,
    $$CalendarCacheTableUpdateCompanionBuilder,
    (
      CalendarCacheData,
      BaseReferences<_$AppDatabase, $CalendarCacheTable, CalendarCacheData>
    ),
    CalendarCacheData,
    PrefetchHooks Function()>;
typedef $$FacultyCacheTableCreateCompanionBuilder = FacultyCacheCompanion
    Function({
  required String slug,
  Value<String> name,
  Value<String> photoUrl,
  Value<String> designation,
  Value<String> department,
  Value<String> emailAddress,
  Value<String> campus,
  Value<String> experience,
  Value<String> researchInterest,
  Value<String> courses,
  Value<String> education,
  Value<String> publications,
  Value<String> awards,
  Value<String> workshops,
  Value<String> workExperience,
  Value<String> memberships,
  Value<String> responsibilities,
  Value<String> profileUrl,
  Value<int> cachedAt,
  Value<int> rowid,
});
typedef $$FacultyCacheTableUpdateCompanionBuilder = FacultyCacheCompanion
    Function({
  Value<String> slug,
  Value<String> name,
  Value<String> photoUrl,
  Value<String> designation,
  Value<String> department,
  Value<String> emailAddress,
  Value<String> campus,
  Value<String> experience,
  Value<String> researchInterest,
  Value<String> courses,
  Value<String> education,
  Value<String> publications,
  Value<String> awards,
  Value<String> workshops,
  Value<String> workExperience,
  Value<String> memberships,
  Value<String> responsibilities,
  Value<String> profileUrl,
  Value<int> cachedAt,
  Value<int> rowid,
});

class $$FacultyCacheTableFilterComposer
    extends Composer<_$AppDatabase, $FacultyCacheTable> {
  $$FacultyCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get designation => $composableBuilder(
      column: $table.designation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get department => $composableBuilder(
      column: $table.department, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emailAddress => $composableBuilder(
      column: $table.emailAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get experience => $composableBuilder(
      column: $table.experience, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get researchInterest => $composableBuilder(
      column: $table.researchInterest,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courses => $composableBuilder(
      column: $table.courses, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get education => $composableBuilder(
      column: $table.education, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get publications => $composableBuilder(
      column: $table.publications, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get awards => $composableBuilder(
      column: $table.awards, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workshops => $composableBuilder(
      column: $table.workshops, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workExperience => $composableBuilder(
      column: $table.workExperience,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memberships => $composableBuilder(
      column: $table.memberships, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get responsibilities => $composableBuilder(
      column: $table.responsibilities,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profileUrl => $composableBuilder(
      column: $table.profileUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$FacultyCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $FacultyCacheTable> {
  $$FacultyCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get designation => $composableBuilder(
      column: $table.designation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get department => $composableBuilder(
      column: $table.department, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emailAddress => $composableBuilder(
      column: $table.emailAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get experience => $composableBuilder(
      column: $table.experience, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get researchInterest => $composableBuilder(
      column: $table.researchInterest,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courses => $composableBuilder(
      column: $table.courses, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get education => $composableBuilder(
      column: $table.education, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get publications => $composableBuilder(
      column: $table.publications,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get awards => $composableBuilder(
      column: $table.awards, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workshops => $composableBuilder(
      column: $table.workshops, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workExperience => $composableBuilder(
      column: $table.workExperience,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memberships => $composableBuilder(
      column: $table.memberships, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get responsibilities => $composableBuilder(
      column: $table.responsibilities,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profileUrl => $composableBuilder(
      column: $table.profileUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$FacultyCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $FacultyCacheTable> {
  $$FacultyCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get designation => $composableBuilder(
      column: $table.designation, builder: (column) => column);

  GeneratedColumn<String> get department => $composableBuilder(
      column: $table.department, builder: (column) => column);

  GeneratedColumn<String> get emailAddress => $composableBuilder(
      column: $table.emailAddress, builder: (column) => column);

  GeneratedColumn<String> get campus =>
      $composableBuilder(column: $table.campus, builder: (column) => column);

  GeneratedColumn<String> get experience => $composableBuilder(
      column: $table.experience, builder: (column) => column);

  GeneratedColumn<String> get researchInterest => $composableBuilder(
      column: $table.researchInterest, builder: (column) => column);

  GeneratedColumn<String> get courses =>
      $composableBuilder(column: $table.courses, builder: (column) => column);

  GeneratedColumn<String> get education =>
      $composableBuilder(column: $table.education, builder: (column) => column);

  GeneratedColumn<String> get publications => $composableBuilder(
      column: $table.publications, builder: (column) => column);

  GeneratedColumn<String> get awards =>
      $composableBuilder(column: $table.awards, builder: (column) => column);

  GeneratedColumn<String> get workshops =>
      $composableBuilder(column: $table.workshops, builder: (column) => column);

  GeneratedColumn<String> get workExperience => $composableBuilder(
      column: $table.workExperience, builder: (column) => column);

  GeneratedColumn<String> get memberships => $composableBuilder(
      column: $table.memberships, builder: (column) => column);

  GeneratedColumn<String> get responsibilities => $composableBuilder(
      column: $table.responsibilities, builder: (column) => column);

  GeneratedColumn<String> get profileUrl => $composableBuilder(
      column: $table.profileUrl, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$FacultyCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FacultyCacheTable,
    FacultyCacheData,
    $$FacultyCacheTableFilterComposer,
    $$FacultyCacheTableOrderingComposer,
    $$FacultyCacheTableAnnotationComposer,
    $$FacultyCacheTableCreateCompanionBuilder,
    $$FacultyCacheTableUpdateCompanionBuilder,
    (
      FacultyCacheData,
      BaseReferences<_$AppDatabase, $FacultyCacheTable, FacultyCacheData>
    ),
    FacultyCacheData,
    PrefetchHooks Function()> {
  $$FacultyCacheTableTableManager(_$AppDatabase db, $FacultyCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FacultyCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FacultyCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FacultyCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> slug = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> photoUrl = const Value.absent(),
            Value<String> designation = const Value.absent(),
            Value<String> department = const Value.absent(),
            Value<String> emailAddress = const Value.absent(),
            Value<String> campus = const Value.absent(),
            Value<String> experience = const Value.absent(),
            Value<String> researchInterest = const Value.absent(),
            Value<String> courses = const Value.absent(),
            Value<String> education = const Value.absent(),
            Value<String> publications = const Value.absent(),
            Value<String> awards = const Value.absent(),
            Value<String> workshops = const Value.absent(),
            Value<String> workExperience = const Value.absent(),
            Value<String> memberships = const Value.absent(),
            Value<String> responsibilities = const Value.absent(),
            Value<String> profileUrl = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FacultyCacheCompanion(
            slug: slug,
            name: name,
            photoUrl: photoUrl,
            designation: designation,
            department: department,
            emailAddress: emailAddress,
            campus: campus,
            experience: experience,
            researchInterest: researchInterest,
            courses: courses,
            education: education,
            publications: publications,
            awards: awards,
            workshops: workshops,
            workExperience: workExperience,
            memberships: memberships,
            responsibilities: responsibilities,
            profileUrl: profileUrl,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String slug,
            Value<String> name = const Value.absent(),
            Value<String> photoUrl = const Value.absent(),
            Value<String> designation = const Value.absent(),
            Value<String> department = const Value.absent(),
            Value<String> emailAddress = const Value.absent(),
            Value<String> campus = const Value.absent(),
            Value<String> experience = const Value.absent(),
            Value<String> researchInterest = const Value.absent(),
            Value<String> courses = const Value.absent(),
            Value<String> education = const Value.absent(),
            Value<String> publications = const Value.absent(),
            Value<String> awards = const Value.absent(),
            Value<String> workshops = const Value.absent(),
            Value<String> workExperience = const Value.absent(),
            Value<String> memberships = const Value.absent(),
            Value<String> responsibilities = const Value.absent(),
            Value<String> profileUrl = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FacultyCacheCompanion.insert(
            slug: slug,
            name: name,
            photoUrl: photoUrl,
            designation: designation,
            department: department,
            emailAddress: emailAddress,
            campus: campus,
            experience: experience,
            researchInterest: researchInterest,
            courses: courses,
            education: education,
            publications: publications,
            awards: awards,
            workshops: workshops,
            workExperience: workExperience,
            memberships: memberships,
            responsibilities: responsibilities,
            profileUrl: profileUrl,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FacultyCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FacultyCacheTable,
    FacultyCacheData,
    $$FacultyCacheTableFilterComposer,
    $$FacultyCacheTableOrderingComposer,
    $$FacultyCacheTableAnnotationComposer,
    $$FacultyCacheTableCreateCompanionBuilder,
    $$FacultyCacheTableUpdateCompanionBuilder,
    (
      FacultyCacheData,
      BaseReferences<_$AppDatabase, $FacultyCacheTable, FacultyCacheData>
    ),
    FacultyCacheData,
    PrefetchHooks Function()>;
typedef $$UserSettingsTableTableCreateCompanionBuilder
    = UserSettingsTableCompanion Function({
  required String academiaEmail,
  Value<String> theme,
  Value<String> defaultView,
  Value<double> attendanceThreshold,
  Value<String> calendarView,
  Value<String> timetableView,
  Value<int> showWeekends,
  Value<int> biometricLockEnabled,
  Value<String?> customSpRelayUrl,
  Value<String> dashboardWidgetsJson,
  Value<String> customDataJson,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$UserSettingsTableTableUpdateCompanionBuilder
    = UserSettingsTableCompanion Function({
  Value<String> academiaEmail,
  Value<String> theme,
  Value<String> defaultView,
  Value<double> attendanceThreshold,
  Value<String> calendarView,
  Value<String> timetableView,
  Value<int> showWeekends,
  Value<int> biometricLockEnabled,
  Value<String?> customSpRelayUrl,
  Value<String> dashboardWidgetsJson,
  Value<String> customDataJson,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$UserSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultView => $composableBuilder(
      column: $table.defaultView, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get calendarView => $composableBuilder(
      column: $table.calendarView, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timetableView => $composableBuilder(
      column: $table.timetableView, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get showWeekends => $composableBuilder(
      column: $table.showWeekends, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get biometricLockEnabled => $composableBuilder(
      column: $table.biometricLockEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customSpRelayUrl => $composableBuilder(
      column: $table.customSpRelayUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dashboardWidgetsJson => $composableBuilder(
      column: $table.dashboardWidgetsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customDataJson => $composableBuilder(
      column: $table.customDataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get theme => $composableBuilder(
      column: $table.theme, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultView => $composableBuilder(
      column: $table.defaultView, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get calendarView => $composableBuilder(
      column: $table.calendarView,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timetableView => $composableBuilder(
      column: $table.timetableView,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get showWeekends => $composableBuilder(
      column: $table.showWeekends,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get biometricLockEnabled => $composableBuilder(
      column: $table.biometricLockEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customSpRelayUrl => $composableBuilder(
      column: $table.customSpRelayUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dashboardWidgetsJson => $composableBuilder(
      column: $table.dashboardWidgetsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customDataJson => $composableBuilder(
      column: $table.customDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTableTable> {
  $$UserSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get defaultView => $composableBuilder(
      column: $table.defaultView, builder: (column) => column);

  GeneratedColumn<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold, builder: (column) => column);

  GeneratedColumn<String> get calendarView => $composableBuilder(
      column: $table.calendarView, builder: (column) => column);

  GeneratedColumn<String> get timetableView => $composableBuilder(
      column: $table.timetableView, builder: (column) => column);

  GeneratedColumn<int> get showWeekends => $composableBuilder(
      column: $table.showWeekends, builder: (column) => column);

  GeneratedColumn<int> get biometricLockEnabled => $composableBuilder(
      column: $table.biometricLockEnabled, builder: (column) => column);

  GeneratedColumn<String> get customSpRelayUrl => $composableBuilder(
      column: $table.customSpRelayUrl, builder: (column) => column);

  GeneratedColumn<String> get dashboardWidgetsJson => $composableBuilder(
      column: $table.dashboardWidgetsJson, builder: (column) => column);

  GeneratedColumn<String> get customDataJson => $composableBuilder(
      column: $table.customDataJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserSettingsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserSettingsTableTable,
    UserSettingsTableData,
    $$UserSettingsTableTableFilterComposer,
    $$UserSettingsTableTableOrderingComposer,
    $$UserSettingsTableTableAnnotationComposer,
    $$UserSettingsTableTableCreateCompanionBuilder,
    $$UserSettingsTableTableUpdateCompanionBuilder,
    (
      UserSettingsTableData,
      BaseReferences<_$AppDatabase, $UserSettingsTableTable,
          UserSettingsTableData>
    ),
    UserSettingsTableData,
    PrefetchHooks Function()> {
  $$UserSettingsTableTableTableManager(
      _$AppDatabase db, $UserSettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<String> theme = const Value.absent(),
            Value<String> defaultView = const Value.absent(),
            Value<double> attendanceThreshold = const Value.absent(),
            Value<String> calendarView = const Value.absent(),
            Value<String> timetableView = const Value.absent(),
            Value<int> showWeekends = const Value.absent(),
            Value<int> biometricLockEnabled = const Value.absent(),
            Value<String?> customSpRelayUrl = const Value.absent(),
            Value<String> dashboardWidgetsJson = const Value.absent(),
            Value<String> customDataJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsTableCompanion(
            academiaEmail: academiaEmail,
            theme: theme,
            defaultView: defaultView,
            attendanceThreshold: attendanceThreshold,
            calendarView: calendarView,
            timetableView: timetableView,
            showWeekends: showWeekends,
            biometricLockEnabled: biometricLockEnabled,
            customSpRelayUrl: customSpRelayUrl,
            dashboardWidgetsJson: dashboardWidgetsJson,
            customDataJson: customDataJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            Value<String> theme = const Value.absent(),
            Value<String> defaultView = const Value.absent(),
            Value<double> attendanceThreshold = const Value.absent(),
            Value<String> calendarView = const Value.absent(),
            Value<String> timetableView = const Value.absent(),
            Value<int> showWeekends = const Value.absent(),
            Value<int> biometricLockEnabled = const Value.absent(),
            Value<String?> customSpRelayUrl = const Value.absent(),
            Value<String> dashboardWidgetsJson = const Value.absent(),
            Value<String> customDataJson = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsTableCompanion.insert(
            academiaEmail: academiaEmail,
            theme: theme,
            defaultView: defaultView,
            attendanceThreshold: attendanceThreshold,
            calendarView: calendarView,
            timetableView: timetableView,
            showWeekends: showWeekends,
            biometricLockEnabled: biometricLockEnabled,
            customSpRelayUrl: customSpRelayUrl,
            dashboardWidgetsJson: dashboardWidgetsJson,
            customDataJson: customDataJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserSettingsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserSettingsTableTable,
    UserSettingsTableData,
    $$UserSettingsTableTableFilterComposer,
    $$UserSettingsTableTableOrderingComposer,
    $$UserSettingsTableTableAnnotationComposer,
    $$UserSettingsTableTableCreateCompanionBuilder,
    $$UserSettingsTableTableUpdateCompanionBuilder,
    (
      UserSettingsTableData,
      BaseReferences<_$AppDatabase, $UserSettingsTableTable,
          UserSettingsTableData>
    ),
    UserSettingsTableData,
    PrefetchHooks Function()>;
typedef $$NotificationSettingsTableTableCreateCompanionBuilder
    = NotificationSettingsTableCompanion Function({
  required String academiaEmail,
  Value<int> attendanceAlertEnabled,
  Value<double> attendanceThreshold,
  Value<int> holidayAlertsEnabled,
  Value<int> pushEnabled,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$NotificationSettingsTableTableUpdateCompanionBuilder
    = NotificationSettingsTableCompanion Function({
  Value<String> academiaEmail,
  Value<int> attendanceAlertEnabled,
  Value<double> attendanceThreshold,
  Value<int> holidayAlertsEnabled,
  Value<int> pushEnabled,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$NotificationSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTableTable> {
  $$NotificationSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attendanceAlertEnabled => $composableBuilder(
      column: $table.attendanceAlertEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get holidayAlertsEnabled => $composableBuilder(
      column: $table.holidayAlertsEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pushEnabled => $composableBuilder(
      column: $table.pushEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$NotificationSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTableTable> {
  $$NotificationSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attendanceAlertEnabled => $composableBuilder(
      column: $table.attendanceAlertEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get holidayAlertsEnabled => $composableBuilder(
      column: $table.holidayAlertsEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pushEnabled => $composableBuilder(
      column: $table.pushEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$NotificationSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTableTable> {
  $$NotificationSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<int> get attendanceAlertEnabled => $composableBuilder(
      column: $table.attendanceAlertEnabled, builder: (column) => column);

  GeneratedColumn<double> get attendanceThreshold => $composableBuilder(
      column: $table.attendanceThreshold, builder: (column) => column);

  GeneratedColumn<int> get holidayAlertsEnabled => $composableBuilder(
      column: $table.holidayAlertsEnabled, builder: (column) => column);

  GeneratedColumn<int> get pushEnabled => $composableBuilder(
      column: $table.pushEnabled, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotificationSettingsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationSettingsTableTable,
    NotificationSettingsTableData,
    $$NotificationSettingsTableTableFilterComposer,
    $$NotificationSettingsTableTableOrderingComposer,
    $$NotificationSettingsTableTableAnnotationComposer,
    $$NotificationSettingsTableTableCreateCompanionBuilder,
    $$NotificationSettingsTableTableUpdateCompanionBuilder,
    (
      NotificationSettingsTableData,
      BaseReferences<_$AppDatabase, $NotificationSettingsTableTable,
          NotificationSettingsTableData>
    ),
    NotificationSettingsTableData,
    PrefetchHooks Function()> {
  $$NotificationSettingsTableTableTableManager(
      _$AppDatabase db, $NotificationSettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSettingsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationSettingsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationSettingsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> academiaEmail = const Value.absent(),
            Value<int> attendanceAlertEnabled = const Value.absent(),
            Value<double> attendanceThreshold = const Value.absent(),
            Value<int> holidayAlertsEnabled = const Value.absent(),
            Value<int> pushEnabled = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationSettingsTableCompanion(
            academiaEmail: academiaEmail,
            attendanceAlertEnabled: attendanceAlertEnabled,
            attendanceThreshold: attendanceThreshold,
            holidayAlertsEnabled: holidayAlertsEnabled,
            pushEnabled: pushEnabled,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String academiaEmail,
            Value<int> attendanceAlertEnabled = const Value.absent(),
            Value<double> attendanceThreshold = const Value.absent(),
            Value<int> holidayAlertsEnabled = const Value.absent(),
            Value<int> pushEnabled = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationSettingsTableCompanion.insert(
            academiaEmail: academiaEmail,
            attendanceAlertEnabled: attendanceAlertEnabled,
            attendanceThreshold: attendanceThreshold,
            holidayAlertsEnabled: holidayAlertsEnabled,
            pushEnabled: pushEnabled,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationSettingsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $NotificationSettingsTableTable,
        NotificationSettingsTableData,
        $$NotificationSettingsTableTableFilterComposer,
        $$NotificationSettingsTableTableOrderingComposer,
        $$NotificationSettingsTableTableAnnotationComposer,
        $$NotificationSettingsTableTableCreateCompanionBuilder,
        $$NotificationSettingsTableTableUpdateCompanionBuilder,
        (
          NotificationSettingsTableData,
          BaseReferences<_$AppDatabase, $NotificationSettingsTableTable,
              NotificationSettingsTableData>
        ),
        NotificationSettingsTableData,
        PrefetchHooks Function()>;
typedef $$NotificationsTableTableCreateCompanionBuilder
    = NotificationsTableCompanion Function({
  required String id,
  required String academiaEmail,
  required String type,
  required String title,
  required String body,
  Value<String> dataJson,
  Value<int> read,
  Value<int> createdAt,
  Value<int> rowid,
});
typedef $$NotificationsTableTableUpdateCompanionBuilder
    = NotificationsTableCompanion Function({
  Value<String> id,
  Value<String> academiaEmail,
  Value<String> type,
  Value<String> title,
  Value<String> body,
  Value<String> dataJson,
  Value<int> read,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$NotificationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationsTableTable> {
  $$NotificationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get read => $composableBuilder(
      column: $table.read, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$NotificationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationsTableTable> {
  $$NotificationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get read => $composableBuilder(
      column: $table.read, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$NotificationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationsTableTable> {
  $$NotificationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get academiaEmail => $composableBuilder(
      column: $table.academiaEmail, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<int> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NotificationsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationsTableTable,
    NotificationsTableData,
    $$NotificationsTableTableFilterComposer,
    $$NotificationsTableTableOrderingComposer,
    $$NotificationsTableTableAnnotationComposer,
    $$NotificationsTableTableCreateCompanionBuilder,
    $$NotificationsTableTableUpdateCompanionBuilder,
    (
      NotificationsTableData,
      BaseReferences<_$AppDatabase, $NotificationsTableTable,
          NotificationsTableData>
    ),
    NotificationsTableData,
    PrefetchHooks Function()> {
  $$NotificationsTableTableTableManager(
      _$AppDatabase db, $NotificationsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> academiaEmail = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> dataJson = const Value.absent(),
            Value<int> read = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationsTableCompanion(
            id: id,
            academiaEmail: academiaEmail,
            type: type,
            title: title,
            body: body,
            dataJson: dataJson,
            read: read,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String academiaEmail,
            required String type,
            required String title,
            required String body,
            Value<String> dataJson = const Value.absent(),
            Value<int> read = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationsTableCompanion.insert(
            id: id,
            academiaEmail: academiaEmail,
            type: type,
            title: title,
            body: body,
            dataJson: dataJson,
            read: read,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotificationsTableTable,
    NotificationsTableData,
    $$NotificationsTableTableFilterComposer,
    $$NotificationsTableTableOrderingComposer,
    $$NotificationsTableTableAnnotationComposer,
    $$NotificationsTableTableCreateCompanionBuilder,
    $$NotificationsTableTableUpdateCompanionBuilder,
    (
      NotificationsTableData,
      BaseReferences<_$AppDatabase, $NotificationsTableTable,
          NotificationsTableData>
    ),
    NotificationsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StudentProfilesTableTableManager get studentProfiles =>
      $$StudentProfilesTableTableManager(_db, _db.studentProfiles);
  $$AttendanceCacheTableTableManager get attendanceCache =>
      $$AttendanceCacheTableTableManager(_db, _db.attendanceCache);
  $$AttendanceSnapshotsTableTableManager get attendanceSnapshots =>
      $$AttendanceSnapshotsTableTableManager(_db, _db.attendanceSnapshots);
  $$TimetableCacheTableTableManager get timetableCache =>
      $$TimetableCacheTableTableManager(_db, _db.timetableCache);
  $$MarksCacheTableTableManager get marksCache =>
      $$MarksCacheTableTableManager(_db, _db.marksCache);
  $$CalendarCacheTableTableManager get calendarCache =>
      $$CalendarCacheTableTableManager(_db, _db.calendarCache);
  $$FacultyCacheTableTableManager get facultyCache =>
      $$FacultyCacheTableTableManager(_db, _db.facultyCache);
  $$UserSettingsTableTableTableManager get userSettingsTable =>
      $$UserSettingsTableTableTableManager(_db, _db.userSettingsTable);
  $$NotificationSettingsTableTableTableManager get notificationSettingsTable =>
      $$NotificationSettingsTableTableTableManager(
          _db, _db.notificationSettingsTable);
  $$NotificationsTableTableTableManager get notificationsTable =>
      $$NotificationsTableTableTableManager(_db, _db.notificationsTable);
}
