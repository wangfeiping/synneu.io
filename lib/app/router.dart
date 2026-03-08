import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/note/domain/note.dart';
import '../features/note/presentation/note_edit_page.dart';
import '../features/note/presentation/note_list_page.dart';
import '../features/project/presentation/project_detail_page.dart';
import '../features/project/presentation/project_list_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const ProjectListPage(),
    ),
    GoRoute(
      path: '/project/:projectId',
      builder: (_, state) => ProjectDetailPage(
        projectId: state.pathParameters['projectId']!,
      ),
      routes: [
        GoRoute(
          path: 'notes',
          builder: (_, state) => NoteListPage(
            projectId: state.pathParameters['projectId']!,
            subPath: state.extra as String? ?? '',
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                final extra = state.extra as (String, Note?)?;
                return NoteEditPage(
                  projectId: projectId,
                  subPath: extra?.$1 ?? '',
                  existingNote: extra?.$2,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('页面不存在：${state.error}')),
  ),
);
