import Foundation

/// Small offline supplement for common vocabulary, proper names and technical terms.
/// These entries protect correct input as well as identify exact layout candidates.
enum LocalLexicon {
    static let words: Set<String> = Set("""
    3D AMD API ASCII Apple B12 BMW Bluetooth COVID-19 CPU ChatGPT Docker GPU GitHub Google H2O HTTP HTTPS I'm
    IT-разработка Intel JSON JavaScript Kubernetes Li Linux MINI Microsoft NFC O'Reilly OpenAI PostgreSQL ProMax
    Python RAM RTX4090 Ryzen SEAT SQL SSD Straße Swift TANK Tesla Toyota TypeScript URL USB UTF WiFi Windows XML
    accessibility algorithm antidisestablishmentarianism application architecture aria art asynchronous
    authentication authorization automatic backend bark beautiful biology blockchain book bread browser cache
    café callback can't cat chair chemistry class client co-operate compile complicated computer concurrency
    configuration constant correction country cryptocurrency dark database debug deploy developer development
    difficult dog don't déjà-vu e-mail electron email encapsulation enum evening façade fiancée frontend
    function goodbye hello hello-world house iPhone15 implementation infrastructure inheritance
    internationalization internet interoperability isn't it's jalapeño keyboard land language lark layout macOS
    mare mars mart mate mathematics milk mini morning mother-in-law mouse mutex namespace naïve neuron neth
    nullable optional park permission physics pneumonoultramicroscopicsilicovolcanoconiosis polymorphism privacy
    protocol quantum race refactor repository responsibility resume road rock'n'roll rollback résumé science
    seat security semaphore serialization server settings simple state-of-the-art struct switch table tank
    thanks thread town variable water welcome won't world überstraße İstanbul АН2 ГОСТ123 ЕГЭ ЖКХ ИНН ИП МИ8 МФЦ
    НДС ООН ООО РФ СНИЛС СССР ТУ154 дарк найс автоматическое авторизация алгоритм антиконституционный апельсин
    ария асинхронность аутентификация бабушка база безопасность бизнес-план биология блокчейн брокер бюро
    веб-сайт ветка вечер взаимодействие виндовс вода всё-таки вчера высококвалифицированный вьюга гипотенуза
    гонка груша данных девочка дедлок дедушка джаваскрипт дифференцирование добро добросовестность докер дом
    достоверность достопримечательность доступность ещё железнодорожный жизнь жюри завтра замыкание здоровье
    здравствуйте из-за из-под инкапсуляция интегрирование интернационализация интернет-магазин инфраструктура
    исключение исправление квантовая кеш клавиатура клиент книга коммит компилятор константа контейнер
    конфиденциальность косинус кошка криптовалюта кто-то кубернетес кэш лайк линукс логарифм логирование любовь
    макос мальчик мама март математика многопоточность молоко мышь мьютекс наследование настройки
    научно-технический нейрон нейросеть неплатёжеспособность ночь образование объявление объём опечатка
    орфография ответственность откат отладчик очередь папа параллелепипед парк переключение переменная питон
    по-русски подъезд пожалуйста полиморфизм постгрес поток привет приложение программирование программист
    протокол пунктуация разработчик разрешение раскладка ребенок ребёнок рентгеноэлектрокардиографический
    репозиторий рефакторинг свифт сегодня сельскохозяйственный семафор семья сервер сериализация синус
    синхрофазотрон слияние собака спасибо стол стул счастье съезд тайпскрипт типизация университет утро физика
    функция химия хлеб цапля что-нибудь школа шоссе щука экземпляр экспонента электрификация электричество
    электрон энциклопедия юла яблоко ёж ёлка
    """.lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
    static let names: Set<String> = Set("""
    Aleksey Alexander Alexei Alexey Alice Amelia Anderson Andrew Ann Anna Anne Anthony Anton Ava Benjamin Björn
    Boris Brown Catherine Charlotte Chen Daniel David Dmitri Dmitry Dostoevsky Einstein Elena Elizabeth Emma
    Ethan Evelyn François Garcia Gates George Harper Harris Harry Henry Ivan Ivanov Jack Jackson Jacob James
    Jane Janet Jobs John Johnson Jones José Julia Julie Kate Katherine Kim Knuth Lee Liam Lovelace Lucas Maria
    Mark Martin Martinez Mary Mason McDonald Mia Michael Mike Muhammad Natalia Natalya Newton Nguyen Nicholas
    Nick Noah O'Connor Olga Oliver Olivia Patel Paul Peter Petr Petrov Pushkin Sergei Sergey Sidorov Singh
    Smirnov Smith Sophia Stanislav Tatiana Tatyana Taylor Tchaikovsky Thomas Thompson Tolstoy Torvalds Turing
    Victor Vladimir Wang White William Williams Zhang Zoë Zuckerberg Łukasz Александр Александра Алексей Алиса
    Андрей Анна Антон Артем Артур Артём Борис Вадим Валерий Валерия Василий Васильев Вера Вероника Виктор
    Владимир Волков Гагарин Галина Георгий Давид Даниил Дарья Денис Дмитрий Достоевский Евгений Евгения Егор
    Екатерина Елена Жан-Поль Зайцев Захар Иван Иванов Игорь Илья Инна Кирилл Ксения Кузнецов Леонид Лесандров
    Лидия Ломоносов Любовь Людмила Максим Марина Мария Марк Менделеев Милана Михаил Морозов Мухаммед Надежда
    Наталия Наталья Никита Николай Нина Новиков Ньютон О'Коннор Олег Ольга Павел Павлова Петр Петров Полина
    Попов Пушкин Пётр Роман Руслан Светлана Семен Семён Сергеева Сергей Сидоров Смирнов Соколов Соловьёв София
    Софья Станислав Татьяна Тимофей Толстой Тьюринг Федор Фёдор Хуан Чайковский Чехов Шрёдингер Эйнштейн Юлия
    Юрий Яна
    """.lowercased().split(whereSeparator: \.isWhitespace).map(String.init))

    static func contains(_ word: String) -> Bool {
        let key = word.lowercased()
        return words.contains(key) || names.contains(key)
    }
}

struct TextToken {
    let leading: String
    let word: String
    let trailing: String

    init(_ token: String) {
        let punctuation = "`[];',.~{}:\"<>«»„“”‘’()!?…"
        var core = token, left = "", right = ""
        while let c = core.first, punctuation.contains(c) { left.append(c); core.removeFirst() }
        while let c = core.last, punctuation.contains(c) { right.insert(c, at: right.startIndex); core.removeLast() }
        leading = left; word = core; trailing = right
    }

    func wrapping(_ replacement: String) -> String { leading + replacement + trailing }

    static func isIdentifier(_ word: String) -> Bool {
        word.contains(where: \.isNumber) || word.contains("_") ||
        word.contains("@") || word.contains("/") || word.contains("\\") ||
        word.contains("://") || word.filter({ $0 == "." }).count > 1 ||
        (word.count <= 2 && word.hasSuffix(":"))
    }

    static func hasProtectedCase(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        return letters.count > 1 && (letters.allSatisfy(\.isUppercase) ||
            letters.dropFirst().contains(where: \.isUppercase))
    }

    static func applyingCase(of original: String, to replacement: String) -> String {
        let letters = original.filter(\.isLetter)
        if !letters.isEmpty && letters.allSatisfy(\.isUppercase) { return replacement.uppercased() }
        if original.first?.isUppercase == true { return replacement.prefix(1).uppercased() + replacement.dropFirst().lowercased() }
        return replacement.lowercased()
    }
}
