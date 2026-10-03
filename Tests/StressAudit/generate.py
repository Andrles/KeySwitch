import json, pathlib, random
root=pathlib.Path(__file__).resolve().parents[2]
en='`qwertyuiop[]asdfghjkl;\'zxcvbnm,.'
ru='ёйцукенгшщзхъфывапролджэячсмитьбю'
pairs=list(zip(en,ru))+[(a.upper(),b.upper()) for a,b in zip(en,ru) if a.isalpha()]+list(zip('~{}:"<>','ЁХЪЖЭБЮ'))
to_en=dict((b,a) for a,b in pairs); to_ru=dict(pairs)
def wrong(w,lang): return ''.join((to_en if lang=='russian' else to_ru).get(c,c) for c in w)
english='''hello world morning evening thanks welcome goodbye beautiful difficult simple complicated language keyboard layout switch correction automatic computer application settings privacy security permission accessibility development developer repository database algorithm asynchronous concurrency serialization authentication authorization configuration infrastructure architecture interoperability implementation responsibility internationalization pneumonoultramicroscopicsilicovolcanoconiosis antidisestablishmentarianism park dark bark lark mart art aria mare mate mars milk bread water book table chair cat dog mouse house road town country science physics chemistry biology mathematics quantum electron neuron blockchain cryptocurrency Docker Kubernetes PostgreSQL JavaScript TypeScript Swift Python Linux Windows macOS GitHub OpenAI ChatGPT API HTTP HTTPS URL JSON XML SQL UTF NFC ASCII CPU GPU RAM SSD USB WiFi Bluetooth email internet browser server client cache thread race mutex semaphore callback frontend backend deploy rollback compile debug refactor namespace protocol enum struct class function variable constant optional nullable polymorphism encapsulation inheritance hello-world state-of-the-art mother-in-law don't can't won't isn't I'm it's O'Reilly rock'n'roll e-mail co-operate resume résumé café naïve déjà-vu jalapeño façade fiancée überstraße İstanbul Straße 3D H2O B12 COVID-19 iPhone15 ProMax RTX4090 AMD Ryzen Intel Apple Microsoft Google Tesla Toyota BMW MINI SEAT TANK Li land seat tank mini god made goat nit rice sea cost fit dot hat rap pie''' .split()
russian='''привет здравствуйте спасибо пожалуйста добро утро вечер ночь сегодня завтра вчера ребёнок ребенок девочка мальчик семья мама папа бабушка дедушка любовь счастье жизнь здоровье школа университет образование программирование программист разработчик приложение настройки разрешение безопасность конфиденциальность доступность клавиатура раскладка переключение автоматическое исправление пунктуация орфография опечатка электричество электрификация достопримечательность высококвалифицированный сельскохозяйственный рентгеноэлектрокардиографический интернационализация асинхронность многопоточность сериализация аутентификация авторизация инфраструктура нейросеть нейрон алгоритм кэш кеш сервер клиент база данных репозиторий коммит ветка слияние откат протокол функция переменная константа экземпляр наследование полиморфизм инкапсуляция компилятор отладчик рефакторинг логирование типизация исключение замыкание семафор мьютекс дедлок гонка поток брокер очередь контейнер докер кубернетес постгрес питон джаваскрипт тайпскрипт свифт линукс виндовс макос криптовалюта блокчейн квантовая физика химия биология математика электрон синхрофазотрон дифференцирование интегрирование экспонента логарифм синус косинус гипотенуза параллелепипед яблоко апельсин груша молоко хлеб вода книга стол стул кошка собака мышь дом парк март ария дарк барк лайк найс ми ни дш дф тв вв МИ8 ТУ154 АН2 ГОСТ123 РФ СССР ООН ООО ИП НДС ИНН СНИЛС ЕГЭ МФЦ ЖКХ IT-разработка веб-сайт интернет-магазин бизнес-план научно-технический из-за из-под всё-таки кто-то что-нибудь по-русски ёж ёлка ещё подъезд съезд объявление объём вьюга счастье бюро жюри щука юла цапля шоссе железнодорожный энциклопедия достоверность взаимодействие добросовестность ответственность антиконституционный неплатёжеспособность'''.split()
names_en='''Alexander Alexey Alexei Aleksey Alice Andrew Anna Anne Ann Anton Anthony Boris Daniel David Dmitry Dmitri Elena George Ivan James Jane Janet John Jack Julia Julie Maria Mary Mark Michael Mike Natalia Natalya Nicholas Nick Olga Paul Peter Petr Sergey Sergei Stanislav Tatiana Tatyana Victor Vladimir Catherine Katherine Kate Harry Henry William Elizabeth Charlotte Sophia Oliver Noah Liam Emma Olivia Amelia Ethan Jacob Benjamin Lucas Mason Ava Mia Harper Evelyn Muhammad José François Björn Zoë Łukasz O'Connor McDonald Smith Brown Johnson Williams Jones Taylor Anderson Thomas Jackson White Harris Martin Thompson Garcia Martinez Lee Kim Chen Wang Zhang Patel Singh Nguyen Ivanov Petrov Sidorov Smirnov Dostoevsky Tchaikovsky Tolstoy Pushkin Einstein Newton Turing Lovelace Knuth Torvalds Jobs Gates Zuckerberg''' .split()
names_ru='''Александр Александра Алексей Алиса Андрей Анна Антон Борис Виктор Владимир Георгий Давид Даниил Дмитрий Елена Екатерина Иван Мария Марк Михаил Наталья Наталия Николай Ольга Павел Пётр Петр Сергей Станислав Татьяна Юлия Артём Артем Артур Вадим Валерий Валерия Василий Вера Вероника Галина Дарья Денис Евгений Евгения Егор Захар Игорь Илья Инна Кирилл Ксения Леонид Лидия Любовь Людмила Максим Марина Милана Надежда Никита Нина Олег Полина Роман Руслан Светлана Семён Семен София Софья Тимофей Фёдор Федор Юрий Яна Иванов Петров Сидоров Смирнов Кузнецов Попов Соколов Новиков Морозов Волков Соловьёв Васильев Зайцев Павлова Сергеева Лесандров Пушкин Толстой Достоевский Чехов Чайковский Менделеев Ломоносов Гагарин Эйнштейн Ньютон Тьюринг Шрёдингер Мухаммед Хуан Жан-Поль О'Коннор''' .split()
cases=[]
def add(kind,input,expected,lang='',group=''):
 cases.append(dict(kind=kind,input=input,expected=expected,language=lang,group=group))
for lang,words in [('english',english+names_en),('russian',russian+names_ru)]:
 for w in dict.fromkeys(words):
  for v in dict.fromkeys([w,w.lower(),w.upper()]):
   add('keep',v,v,lang,'curated')
   add('layout',wrong(v,lang),v,lang,'curated')
  add('spell',w,w,lang,'correct-word')
# Punctuation attached to known words; engine direct and monitor-style streaming.
for lang,w in [('russian','привет'),('english','hello'),('russian','спасибо'),('english','park')]:
 for left,right in [('',','),('','.'),('','...'),('',';'),('',':'),('','!'),('','?'),('"','"'),("'","'"),('«','»'),('(',' )'),('[',']'),('“','”'),('','…')]:
  inp=left+wrong(w,lang)+right
  add('layout',inp,left+w+right,lang,'punctuation')
  add('stream',inp+' ',left+w+right+' ',lang,'punctuation')
  add('stream',left+w+right+' ',left+w+right+' ',lang,'correct-punctuation')
for s in ['hello, world!','привет, мир!','park dark mart aria','Привет, hello!','support@example.com','ivan.petrov@gmail.com','https://github.com/Andrles/KeySwitch','https://example.com/park?q=hello','foo_bar = new Map();','let dark = true;','git checkout main','npm install react','C:\\Users\\Ivan\\Desktop','/Users/ivan/park','192.168.1.1','v3.1.0','ABC-123','МИ8 ТУ154 АН2','NFC ё й ё й','🚀 привет 👨‍👩‍👧‍👦 hello','O’Connor Jean–Paul','пароль: qwerty123']:
 add('stream',s+' ',s+' ','','structured')
# Tab is a navigation reset in monitor; newline is a correction boundary.
for sep in [' ','\n','\t','!','?','/','@']:
 # Technical separators may belong to an address/path; conservative policy keeps the token.
 add('stream',wrong('привет','russian')+sep,(wrong('привет','russian') if sep in ['/', '@'] else 'привет')+sep,'russian','boundaries')
for lang,typos in [('english',['helo','Helo','HELO','recieve','Recieve','RECIEVE','adress','Adress','ADRESS','teh','langauge','definately','occured','seperate','accomodate','wierd','quikc','programmng']),('russian',['превет','Превет','ПРЕВЕТ','малако','Малако','МАЛАКО','пожалуйсто','здраствуйте','програмирование','симпотичный','агенство','будующий','сдесь','жыраф','щюка','жы'])]:
 for t in typos: add('probe-spell',t,'',lang,'typo')
for lang in ['russian','english']:
 for n in [1,2,63,64,65,100,1000,10000]:
  w=('я' if lang=='russian' else 'a')*n
  add('robust',w,w,lang,'length')
# Seeded property corpus: conversion invertible for characters with known mapping.
r=random.Random(20261003)
for i in range(3000):
 lang='english' if i%2==0 else 'russian'
 alphabet=en+'ABCDEFGHIJKLMNOPQRSTUVWXYZ' if lang=='english' else ru+ru.upper()
 w=''.join(r.choice(alphabet) for _ in range(r.randint(1,64)))
 add('roundtrip',w,w,lang,'seed-20261003')
# Broad English lexicon, exploratory only (archaic entries and language collisions possible).
p=pathlib.Path('/usr/share/dict/words')
if p.exists():
 ws=[w for w in p.read_text().splitlines() if w.isascii() and w.isalpha() and 3<=len(w)<=24]
 for w in r.sample(ws,min(3000,len(ws))): add('keep-exploratory',w,w,'english','web2-sample')
# Protect ordinary valid vocabulary even when punctuation changes dictionary scoring.
for lang,words in [('english',english),('russian',russian)]:
 for w in dict.fromkeys(words):
  for p in [',','.',':',"'",'...', '!','?']:
   add('keep',w+p,w+p,lang,'valid-punctuation')
for w in 'пишешь говоришь идёт идет шёл шел сделала сделал сделали работу работаю работал работает программирование программирования программированием человек человека человеку человеком люди людей людям детьми детям ребёнка ребенка ученики учащиеся формула формулы формуле задачи задачам уравнение уравнения разрабатываем реализовать реализуем проверили проверяем проверяется исправить исправили ошибка ошибки ошибок именем имени имена фамилия фамилии отчество отчеством русская русские английские английская переключается переключалось переключаться нарисовать нарисовали создаём создаем установлено установили установщик проверка проверку проверкой проверке меняем меняется меняются выбрал выбрали выбрать выбираем фотографии фотография фотографию обновить обновили обновление обновлением синхронизация синхронизацией зарегистрирован регистрация разработанный разработана учебник учебники учебником инженер инженеры инженера инженеру терминология терминологический вычисление вычисления вычисляется вычисляем автоматизированная автоматизированный автоматизированного параллельно последовательно'.split():
 add('keep',w,w,'russian','morphology')
 add('layout',wrong(w,'russian'),w,'russian','morphology')
 add('spell',w,w,'russian','morphology')
for s in ['Chen Petr Александра Наталия Инна Семён ','из-за ещё ЖКХ ','API UTF NFC BMW AMD РФ СССР ООН НДС ИНН ЕГЭ МФЦ ','асинхронность аутентификация инкапсуляция криптовалюта ','GitHub OpenAI macOS ProMax Ryzen ','коммит наследование экспонента ']:
 add('stream-auto-keep',s,s,'','known-valid-auto')
(root/'Tests/StressAudit/cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2))
print(f'Expanded: {len(cases)} cases')
