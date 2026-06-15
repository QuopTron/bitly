import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bitly/features/home/domain/entities/home_section.dart';
import 'package:bitly/features/home/data/repositories/home_repository.dart';
import 'package:bitly/features/home/presentation/bloc/home_bloc.dart';
import 'package:bitly/features/home/presentation/bloc/home_event.dart';
import 'package:bitly/features/home/presentation/bloc/home_state.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late HomeRepository repository;
  late HomeBloc homeBloc;

  setUp(() {
    repository = MockHomeRepository();
    homeBloc = HomeBloc(repository: repository);
  });

  tearDown(() {
    homeBloc.close();
  });

  group('HomeBloc', () {
    const testSections = [
      HomeSection(
        title: 'Test Section',
        type: SectionType.recent,
        items: [],
      ),
    ];

    test('initial state is correct', () {
      expect(homeBloc.state, const HomeState());
    });

    blocTest<HomeBloc, HomeState>(
      'emits [loading, loaded] when LoadHome succeeds',
      build: () => homeBloc,
      setUp: () {
        when(() => repository.getHomeSections())
            .thenAnswer((_) async => testSections);
      },
      act: (bloc) => bloc.add(const LoadHome()),
      expect: () => [
        const HomeState(isLoading: true),
        const HomeState(sections: testSections, isLoading: false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [loading, error] when LoadHome fails',
      build: () => homeBloc,
      setUp: () {
        when(() => repository.getHomeSections())
            .thenThrow(Exception('Network error'));
      },
      act: (bloc) => bloc.add(const LoadHome()),
      expect: () => [
        const HomeState(isLoading: true),
        const HomeState(
          isLoading: false,
          error: 'Error al cargar la página principal',
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits loading again and reloads on RefreshHome',
      build: () => homeBloc,
      setUp: () {
        when(() => repository.getHomeSections())
            .thenAnswer((_) async => testSections);
      },
      act: (bloc) => bloc.add(const RefreshHome()),
      expect: () => [
        const HomeState(isLoading: true),
        const HomeState(sections: testSections, isLoading: false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'swallows error on RefreshHome',
      build: () => homeBloc,
      setUp: () {
        when(() => repository.getHomeSections())
            .thenThrow(Exception('fail'));
      },
      act: (bloc) => bloc.add(const RefreshHome()),
      expect: () => [
        const HomeState(isLoading: true),
        const HomeState(isLoading: false),
      ],
    );
  });
}
