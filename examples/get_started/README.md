# Запуск кластера через Docker Compose

В этом руководстве показано, как запустить кластер Tarantool Database (RESP) с помощью Docker Compose.

> [!NOTE]
> Развертывание Tarantool Database (RESP) через Docker-образ используется в ознакомительных целях и
> рассчитано на использование в примерах документации и при тестировании.
> Для целевого развертывания используйте штатные средства установки.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Используемые файлы](#используемые-файлы)
* [Конфигурация контейнера для узла Tarantool Database (RESP)](#конфигурация-контейнера-для-узла-tarantool-database-resp)
* [Контейнер init](#контейнер-init)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный Docker-образ Tarantool Database (RESP).
  Пример использует локальный образ с тегом `tdb_redis:2x-latest` — он указан в поле `image` всех контейнеров
  в `docker-compose.yml`;
* приложение Docker Compose;
* исходные файлы примера `get_started`;
* утилита `redis-cli` — для проверки работы (не обязательна).

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-resp-examples](https://github.com/tarantool/tarantooldb-resp-examples/tree/release-2x/master).
>    Пример `get_started` расположен в директории `examples/get_started`.
>  * Отдельный архив [get_started.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-resp-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fget_started&filename=get_started), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `get_started`:

```shell
cd examples/get_started
```

Запустите кластер Tarantool Database (RESP):

```shell
make start
```

Команда запускает стенд и дожидается готовности его портов.
Порядок запуска контейнеров определяется зависимостями между ними:

1. Запускается централизованное хранилище конфигурации — кластер из 3 узлов Tarantool.
2. Загружается конфигурация кластера в централизованное хранилище (контейнер `init`).
3. Запускаются контейнер `failover` (координатор аварийного переключения в режиме `supervised`) и 3 экземпляра Tarantool Database (RESP).

Запущенный стенд состоит из следующих компонентов:

- кластер Tarantool Database (RESP): 1 мастер-узел и 2 реплики (RESP-порты 46379, 46380, 46381);
- компонент Redis Sentinel — по одному в каждом экземпляре Tarantool Database (RESP) (порты 36379, 36380, 36381);
- контейнер `failover` — координатор supervised failover;
- кластер централизованного хранилища конфигурации из 3 узлов.

После запуска должны работать все контейнеры, кроме [init](#контейнер-init).
Также после запуска кластер становится доступен для Redis-клиентов, проверить это можно так:

```shell
redis-cli -p 46379 ping                              # PONG
redis-cli -p 36379 sentinel master storages001       # статус мастер-узла
```

## Используемые файлы

В руководстве используются следующие файлы примера `get_started`:

* `Makefile` — инструкции для утилиты `make` для запуска и остановки всего стенда;
* `docker-compose.yml` — описание всех узлов стенда;
* `init.sh` — скрипт, который выполняется в контейнере `init`;
* `wait.sh` — скрипт, который дожидается готовности кластера (вызывается командой `make start`);
* `cluster/config_storage/` — директория с файлами конфигурации централизованного хранилища:
  * `config.yaml` — топология хранилища конфигурации;
* `cluster/tdbredis/` — директория с файлами конфигурации кластера Tarantool Database (RESP):
  * `config.yaml` — адреса централизованного хранилища конфигурации;
  * `source.yaml` — топология кластера Tarantool Database (RESP), которая публикуется в централизованное хранилище конфигурации контейнером `init`.

## Конфигурация контейнера для узла Tarantool Database (RESP)

Конфигурация контейнера для узла Tarantool Database (RESP) задается в файле `docker-compose.yml`:

```yaml
tdbredis-1:
  image: tdb_redis:2x-latest
  volumes:
    - ./cluster/tdbredis:/tdb_redis/instances.enabled/tdbredis
  command: ["tarantool", "--name", "instance001", "--config", "instances.enabled/tdbredis/config.yaml"]
  ports:
    - "46379:6379"
    - "36379:26379"
```

Здесь:
* `image` — название Docker-образа, используемого для создания контейнера;
* `volumes` — директория с конфигурацией кластера, монтируется в контейнер;
* `command` — запуск экземпляра Tarantool:
  * `--name` — имя экземпляра из топологии в `source.yaml`;
  * `--config` — путь к файлу конфигурации;
* `ports` — проброс RESP-порта экземпляра и порта Sentinel на хост.
  Sentinel работает как роль `tdb_redis_sentinel` внутри каждого экземпляра. Хост-порты выбраны вне портов
  Redis по умолчанию (6379 и 26379), чтобы стенд не конфликтовал с Redis, запущенным на хосте.

## Контейнер init

В файле `docker-compose.yml` есть специальный контейнер `init`.
С этого контейнера выполняется загрузка конфигурации кластера Tarantool Database (RESP)
в централизованное хранилище: публикация топологии из `cluster/tdbredis/source.yaml` с помощью команды
 `tt cluster publish`.

После успешной публикации контейнер завершает работу. Остальные узлы запускаются
по цепочке зависимостей (`depends_on`) из файла `docker-compose.yml`.
Контейнер `failover` запускается после завершения работы `init`, экземпляры Tarantool Database (RESP) — после запуска `failover`.

## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
