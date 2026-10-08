import 'dart:io';
import 'package:dart_pptx/dart_pptx.dart';
import 'package:dart_pptx/src/classes/layout.dart';

void main() async {
  final pres = PowerPoint();

  // Metadata
  pres.title = 'NIT Goa - Attendance & Course Management System';
  pres.subject = 'College-wide Mobile Application';
  pres.author = 'NIT Goa';
  pres.company = 'NIT Goa';
  pres.layout = Layout.screen16x9();
  pres.showSlideNumbers = true;

  // ═══════════════════════════════════════════
  // SLIDE 1: Title Slide (Dark Blue)
  // ═══════════════════════════════════════════
  final slide1 = pres.addTitleSlide(
    title: 'Attendance & Course\nManagement System'.toTextValue(),
    author: 'NIT Goa  |  Mobile Application Project'.toTextValue(),
  );
  slide1.background.color = '0D47A1';
  slide1.speakerNotes = 'Introduce the project — a college-wide mobile app built with Flutter and Firebase for NIT Goa.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 2: Problem Statement (Dark Red)
  // ═══════════════════════════════════════════
  final slide2 = pres.addTitleAndBulletsSlide(
    title: 'The Problem'.toTextValue(),
    subtitle: 'Challenges with Traditional Register System'.toTextValue(),
    bullets: [
      'Manual paper registers are time-consuming and error-prone',
      'No real-time attendance tracking or percentage calculation',
      'Difficult to search, filter, or export attendance data',
      'Registers can be lost, damaged, or tampered with',
      'Professors spend 10-15 minutes per class on roll calls',
      'Students have ZERO visibility into their attendance percentage',
      'End-of-semester data compilation is tedious and manual',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide2.background.color = '2C3E50';
  slide2.speakerNotes = 'Explain the pain points of traditional paper-based attendance that every college faces.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 3: Comparison — Traditional vs Digital (Image)
  // ═══════════════════════════════════════════
  final slide3 = pres.addTitleAndPhotoAltSlide(
    title: 'Traditional vs Digital'.toTextValue(),
    subtitle: 'A complete paradigm shift'.toTextValue(),
    image: ImageReference(
      path: './images/comparison.png',
      name: 'Traditional vs Digital Comparison',
    ),
  );
  slide3.background.color = '1A1A2E';
  slide3.speakerNotes = 'Show the visual comparison between the old paper system and our new digital solution.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 4: Our Solution (Deep Purple)
  // ═══════════════════════════════════════════
  final slide4 = pres.addTitleAndBulletsSlide(
    title: 'Our Solution'.toTextValue(),
    subtitle: 'A role-based mobile application for NIT Goa'.toTextValue(),
    bullets: [
      'Cross-platform Flutter app (Android and iOS)',
      'Cloud-powered with Google Firebase (real-time sync)',
      'Secure Google SSO — restricted to @nitgoa.ac.in',
      '5 role-based portals: Moderator, Admin, Professor, CR, Student',
      'Lecture-wise attendance with instant percentage calculation',
      'Downloadable reports in CSV, Excel, and PDF formats',
      'Works offline — syncs automatically when back online',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide4.background.color = '1B1464';
  slide4.speakerNotes = 'Present the solution overview — a complete digital attendance and course management system.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 5: System Architecture (Image)
  // ═══════════════════════════════════════════
  final slide5 = pres.addTitleAndPhotoAltSlide(
    title: 'System Architecture'.toTextValue(),
    subtitle: '5 roles connected through Flutter and Firebase'.toTextValue(),
    image: ImageReference(
      path: './images/architecture.png',
      name: 'System Architecture Diagram',
    ),
  );
  slide5.background.color = '0A1628';
  slide5.speakerNotes = 'Walk through the system architecture — 5 user roles, Flutter frontend, Firebase backend with Auth, Firestore, and Storage.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 6: Role-Based Architecture (Dark)
  // ═══════════════════════════════════════════
  final slide6 = pres.addTitleAndBulletsSlide(
    title: 'Role-Based Access Control'.toTextValue(),
    subtitle: '5 distinct roles with specific permissions'.toTextValue(),
    bullets: [
      'MODERATOR — Manages branches, courses, user roles, CR assignment, semester reset',
      'ADMIN — Assigns professors to courses created by the Moderator',
      'PROFESSOR — Marks attendance, views reports, approves enrollment, downloads data',
      'CR (Class Rep) — Marks attendance, approves enrollment + has Student portal',
      'STUDENT — Enrolls in courses, views attendance percentage, manages profile',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide6.background.color = '16213E';
  slide6.speakerNotes = 'Walk through each role and their responsibilities in the system.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 7: Key Features (Teal Dark)
  // ═══════════════════════════════════════════
  final slide7 = pres.addTitleAndBulletsSlide(
    title: 'Key Features'.toTextValue(),
    subtitle: 'What makes this system powerful'.toTextValue(),
    bullets: [
      'Lecture-wise attendance (multiple sessions per day per course)',
      'Color-coded attendance: Green >80%  |  Yellow 75-80%  |  Red <75%',
      'Course enrollment with approval workflow (Professor or CR)',
      'Editable attendance records (by Professor and CR)',
      'First-year section support + branch-wise for Years 2-4',
      'Semester reset with full data archival and download',
      'Offline attendance marking with automatic cloud sync',
      'Export: day-wise, month-wise, full semester (CSV / Excel / PDF)',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide7.background.color = '0B3D45';
  slide7.speakerNotes = 'Highlight each feature and explain its benefit to both faculty and students.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 8: Technology Stack (Dark Blue-Grey)
  // ═══════════════════════════════════════════
  final slide8 = pres.addTitleAndBulletsSlide(
    title: 'Technology Stack'.toTextValue(),
    subtitle: 'Built with modern, production-grade technologies'.toTextValue(),
    bullets: [
      'Frontend  —  Flutter (Dart) for cross-platform Android + iOS',
      'Backend  —  Firebase (Serverless BaaS by Google)',
      'Auth  —  Firebase Authentication + Google Sign-In',
      'Database  —  Cloud Firestore (NoSQL, real-time, offline-capable)',
      'Storage  —  Firebase Storage for export file archives',
      'Offline  —  Local caching with automatic sync on reconnection',
      'Export  —  CSV, Excel, PDF packages for report generation',
      'UI  —  Google Fonts, Shimmer loading, Material Design 3',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide8.background.color = '1A237E';
  slide8.speakerNotes = 'Explain why each technology was chosen — Flutter for cross-platform, Firebase for serverless backend.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 9: Attendance Workflow (Image)
  // ═══════════════════════════════════════════
  final slide9 = pres.addTitleAndPhotoAltSlide(
    title: 'Attendance Workflow'.toTextValue(),
    subtitle: 'From marking to reporting — 8 simple steps'.toTextValue(),
    image: ImageReference(
      path: './images/workflow.png',
      name: 'Attendance Workflow Diagram',
    ),
  );
  slide9.background.color = '0A1628';
  slide9.speakerNotes = 'Walk through the complete attendance flow step by step — from marking to export.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 10: Advantages Over Traditional System (Green-Dark)
  // ═══════════════════════════════════════════
  final slide10 = pres.addTitleAndBulletsSlide(
    title: 'Advantages Over Traditional System'.toTextValue(),
    subtitle: '9 reasons why digital is the future'.toTextValue(),
    bullets: [
      'SPEED  —  Attendance in 2-3 min vs 10-15 min with paper',
      'ACCURACY  —  No miscounting, no illegible handwriting errors',
      'SECURITY  —  Cloud-backed, tamper-proof, role-restricted access',
      'ANALYTICS  —  Instant attendance %, color-coded warnings',
      'ACCESSIBILITY  —  Students check attendance anytime, anywhere',
      'EXPORTABILITY  —  Download reports in CSV / Excel / PDF instantly',
      'RESILIENCE  —  Works offline, no risk of lost registers',
      'ECO-FRIENDLY  —  Zero paper usage, fully digital workflow',
      'ARCHIVAL  —  Clean semester reset with systematic data backup',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide10.background.color = '1B4332';
  slide10.speakerNotes = 'Emphasize the tangible benefits — speed, accuracy, security, and accessibility.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 11: Data Model & Security (Dark Grey)
  // ═══════════════════════════════════════════
  final slide11 = pres.addTitleAndBulletsSlide(
    title: 'Data Model and Security'.toTextValue(),
    subtitle: 'Cloud Firestore — 7 collections with role-based security rules'.toTextValue(),
    bullets: [
      'users  —  Profiles, roles, academic info (UID-keyed)',
      'branches  —  Branch definitions (ECE, CSE, ME, etc.)',
      'courses  —  Course catalog (branch, year, semester, professor)',
      'enrollments  —  Student-to-Course mappings (approved)',
      'enrollmentRequests  —  Pending join requests with status tracking',
      'attendanceSessions  —  Lecture sessions with present/absent stats',
      'records (sub-collection)  —  Individual student attendance per lecture',
      'Firestore Security Rules  —  Strict role-based read/write enforcement',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide11.background.color = '212529';
  slide11.speakerNotes = 'Show the database structure and how security is enforced through Firestore rules.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 12: Development Roadmap (Dark Indigo)
  // ═══════════════════════════════════════════
  final slide12 = pres.addTitleAndBulletsSlide(
    title: 'Development Roadmap'.toTextValue(),
    subtitle: '8-phase approach from foundation to deployment'.toTextValue(),
    bullets: [
      'Phase 1  —  Foundation: Flutter + Firebase setup, Auth, Role routing',
      'Phase 2  —  Moderator Portal: Branches, Courses, Roles, CR assignment',
      'Phase 3  —  Admin Portal: Professor-to-Course assignment',
      'Phase 4  —  Professor Portal: Mark / Edit / View attendance, Approvals',
      'Phase 5  —  CR Portal: Attendance + Enrollment handling',
      'Phase 6  —  Student Portal: Browse courses, Apply, View attendance',
      'Phase 7  —  Advanced: Offline sync, Export (CSV/Excel/PDF), Semester reset',
      'Phase 8  —  Polish: UI/UX refinement, Testing, Performance optimization',
    ].map((e) => e.toTextValue()).toList(),
  );
  slide12.background.color = '1A1A40';
  slide12.speakerNotes = 'Present the phased development plan and timeline.'.toTextValue();

  // ═══════════════════════════════════════════
  // SLIDE 13: Thank You (Gradient Blue)
  // ═══════════════════════════════════════════
  final slide13 = pres.addTitleSlide(
    title: 'Thank You'.toTextValue(),
    author: 'Questions & Discussion'.toTextValue(),
  );
  slide13.background.color = '0D47A1';
  slide13.speakerNotes = 'Open the floor for questions from the professors.'.toTextValue();

  // Save the file
  final bytes = await pres.save();
  if (bytes != null) {
    final outputPath = r'c:\Users\jeffj\Desktop\ATTENDENCE SYSTEM\NIT_Goa_Attendance_System_Presentation.pptx';
    final file = File(outputPath);
    await file.writeAsBytes(bytes);
    print('Presentation saved to: $outputPath');
    print('Total slides: 13 (12 content + 1 thank you)');
  } else {
    print('Failed to generate presentation');
  }
}
