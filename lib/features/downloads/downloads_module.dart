import 'package:get_it/get_it.dart';
import 'data/datasources/download_local_source.dart';
import 'data/datasources/download_remote_source.dart';
import 'data/repositories/download_repository.dart';
import 'data/repositories/queue_repository.dart';
import 'domain/usecases/add_to_queue.dart';
import 'domain/usecases/start_download.dart';
import 'domain/usecases/cancel_download.dart';
import 'domain/usecases/get_queue.dart';
import 'domain/usecases/get_history.dart';
import 'domain/usecases/retry_download.dart';
import 'presentation/bloc/queue_bloc/queue_bloc.dart';
import 'presentation/bloc/history_bloc/history_bloc.dart';
import 'presentation/bloc/progress_bloc/progress_bloc.dart';
import '../../core/api/methods.dart';

class DownloadsModule {
  static void register() {
    final sl = GetIt.instance;

    sl.registerLazySingleton<DownloadLocalSource>(
        () => DownloadLocalSource());
    sl.registerLazySingleton<DownloadRemoteSource>(
        () => DownloadRemoteSource(sl<DownloadMethods>()));

    sl.registerLazySingleton<DownloadRepository>(() =>
        DownloadRepository(
            sl<DownloadLocalSource>(), sl<DownloadRemoteSource>()));
    sl.registerLazySingleton<QueueRepository>(
        () => QueueRepository(sl<DownloadLocalSource>()));

    sl.registerLazySingleton<AddToQueueUseCase>(
        () => AddToQueueUseCase(sl<QueueRepository>()));
    sl.registerLazySingleton<StartDownload>(
        () => StartDownload(sl<DownloadRepository>()));
    sl.registerLazySingleton<CancelDownload>(
        () => CancelDownload(sl<DownloadRepository>()));
    sl.registerLazySingleton<GetQueue>(
        () => GetQueue(sl<QueueRepository>()));
    sl.registerLazySingleton<GetHistory>(
        () => GetHistory(sl<DownloadRepository>()));
    sl.registerLazySingleton<RetryDownload>(
        () => RetryDownload(sl<DownloadRepository>()));

    sl.registerFactory<QueueBloc>(
        () => QueueBloc(sl<QueueRepository>()));
    sl.registerFactory<HistoryBloc>(
        () => HistoryBloc(sl<DownloadRepository>()));
    sl.registerFactory<ProgressBloc>(() =>
        ProgressBloc(sl<DownloadRemoteSource>(),
            sl<DownloadLocalSource>()));
  }
}
