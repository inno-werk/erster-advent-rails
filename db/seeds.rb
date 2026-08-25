# This file ensures the existence of records required to run the application in every environment.
# Run with `bin/rails db:seed` (or alongside the database with `db:setup`).

puts "Clearing existing seed data..."

Order.delete_all
Product.delete_all
Payment.delete_all
Business.destroy_all
User.destroy_all
CmsBlock.destroy_all
SiteSetting.delete_all
ActionText::RichText.delete_all if defined?(ActionText::RichText)
ActiveStorage::Attachment.delete_all if defined?(ActiveStorage::Attachment)
ActiveStorage::Blob.delete_all if defined?(ActiveStorage::Blob)

def confirmed_user!(attributes)
  user = User.new(attributes)
  user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
  user.confirmed_at ||= Time.current if user.respond_to?(:confirmed_at)
  user.save!
  user
end

def image_asset(filename)
  Rails.root.join("app/assets/images/#{filename}")
end

def attach_asset!(record, attachment_name, filename)
  path = image_asset(filename)
  return unless path.exist?

  record.public_send(attachment_name).attach(
    io: File.open(path),
    filename: File.basename(path),
    content_type: "image/png"
  )
end

confirmed_user!(
  email: "superadmin@erster-advent-bern.ch",
  password: "kiskec-sankA0-dypxuh",
  role: 2,
  name: "Erster Advent Bern",
  business_name: "Verein Erster Advent",
  address: "Postgasse 20\n3011 Bern",
  phone: "+41 31 311 11 11",
  category: "Organisation"
)

confirmed_user!(
  email: "admin@erster-advent-bern.ch",
  password: "bern-admin-2026",
  role: 1,
  name: "Leitung Untere Altstadt",
  business_name: "Erster Advent Bern",
  address: "Kramgasse 1\n3011 Bern",
  phone: "+41 31 312 24 24",
  category: "Administration"
)

businesses = [
  {
    email: "postgass.stube@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Mara Stucki",
    business_name: "Postgass Stube",
    phone: "+41 31 311 20 01",
    address: "Postgasse 12\n3011 Bern",
    categories: [ "Essen & Trinken", "Saisonaler Markt" ],
    tags: [ "Unter Altstadt", "Fondue", "Aare" ],
    website: "https://erster-advent-bern.ch/postgass-stube",
    instagram: "https://instagram.com/postgassstube",
    map_query: "Postgasse 12 Bern",
    image: "home/bild_1.png",
    gallery: [ "home/bild_2.png", "home/bild_3.png", "home/bild_4.png" ],
    description: "Warme Kueche, Kerzenlicht und ein kleiner Adventstresen mitten in der Postgasse. Die Postgass Stube serviert am Ersten Advent Berner Klassiker in handlicher Form: kleine Fonduebroetli, hausgemachten Apfelpunsch und Suppen aus regionalem Gemuese. Der Betrieb ist seit Jahren Treffpunkt fuer Nachbarinnen, Handwerker und Besucherinnen der Unteren Altstadt.",
    specialities: [
      "Mini-Fondue im Broetli mit Greyerzer und Vacherin",
      "Heisser Apfelpunsch mit Berner Honig, auch alkoholfrei",
      "Sitzplaetze im Gewoelbekeller fuer kurze Waermepausen"
    ],
    products: [
      [ "Postgass Punschsirup", "Konzentrierter Apfel-Zimt-Sirup fuer winterliche Abende zuhause. Gekocht mit Most aus dem Berner Mittelland und Gewuerzen aus der Stube.", 14.50, [ "250 ml", "500 ml" ], "1-2 Tage" ],
      [ "Fondue-Gewuerz Bern", "Kleine Gewuerzmischung mit Pfeffer, Muskat und Knoblauch fuer das klassische Adventsfondue.", 8.90, [ "Glas 45 g" ], "Sofort abholbereit" ]
    ]
  },
  {
    email: "laubenwerk@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Nils Gfeller",
    business_name: "Laubenwerk Bern",
    phone: "+41 31 312 44 08",
    address: "Kramgasse 46\n3011 Bern",
    categories: [ "Handgemachte Waren", "Dekoration" ],
    tags: [ "Lauben", "Holz", "Handwerk" ],
    website: "https://erster-advent-bern.ch/laubenwerk",
    instagram: "https://instagram.com/laubenwerkbern",
    map_query: "Kramgasse 46 Bern",
    image: "home/bild_2.png",
    gallery: [ "home/bild_1.png", "home/bild_5.png", "home/bild_6.png" ],
    description: "Laubenwerk fertigt kleine Serien aus Schweizer Holz: Kerzenhalter, Baumschmuck, Kartenstaender und reduzierte Wohnaccessoires. Am Ersten Advent arbeitet die Werkstatt im Schaufenster und zeigt, wie aus altem Kirschbaumholz neue Lieblingsstuecke fuer die Festtage entstehen.",
    specialities: [
      "Live-Schnitzen unter den Lauben von 12 bis 16 Uhr",
      "Personalisierte Holzanhanger mit Namen oder Jahrgang",
      "Kleine Geschenkverpackung aus Recyclingpapier inklusive"
    ],
    products: [
      [ "Zytglogge Holzornament", "Fein geschliffener Christbaumanhaenger aus Schweizer Nussbaum, inspiriert von den Formen der Berner Altstadt.", 18.00, [ "Einzelstueck", "3er Set" ], "2-3 Tage" ],
      [ "Lauben Kerzenbank", "Schlichte Kerzenbank aus geoltem Eschenholz fuer vier Adventskerzen.", 54.00, [ "Natur", "Dunkel geoelt" ], "3-5 Tage" ],
      [ "Aare Kartenhalter", "Kleiner Kartenhalter aus Restholz, passend fuer Menuekarten, Fotos oder Adventsgruesse.", 12.00, [ "Klein", "Gross" ], "Sofort abholbereit" ]
    ]
  },
  {
    email: "aaregold@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Livia Fahrni",
    business_name: "Aaregold Schmuckatelier",
    phone: "+41 31 312 18 70",
    address: "Gerechtigkeitsgasse 54\n3011 Bern",
    categories: [ "Schmuck", "Handgemachte Waren" ],
    tags: [ "Goldschmiede", "Unikate", "Bern" ],
    website: "https://erster-advent-bern.ch/aaregold",
    instagram: "https://instagram.com/aaregoldbern",
    map_query: "Gerechtigkeitsgasse 54 Bern",
    image: "home/bild_3.png",
    gallery: [ "home/bild_2.png", "home/bild_6.png", "home/bild_7.png" ],
    description: "Aaregold ist ein kleines Schmuckatelier fuer klare Formen, reparierte Erbstuecke und neue Unikate. Die Kollektion zum Ersten Advent greift Linien der Aare, Laubenbogen und Sandsteinfarben auf. Besucherinnen koennen vor Ort Gravuren besprechen und Materialien anfassen.",
    specialities: [
      "Kostenlose Ringgroessen-Beratung am Veranstaltungstag",
      "Limitierte Aare-Linie in Silber und vergoldetem Messing",
      "Reparatursprechstunde fuer Lieblingsstuecke"
    ],
    products: [
      [ "Aarelinie Silberring", "Schmaler Silberring mit weich geschwungener Linie, von Hand poliert im Atelier an der Gerechtigkeitsgasse.", 118.00, [ "50", "52", "54", "56", "58" ], "5-7 Tage" ],
      [ "Laubenbogen Ohrstecker", "Dezente Ohrstecker aus recyceltem Silber, inspiriert von den Rundungen der Berner Lauben.", 76.00, [ "Silber", "Vergoldet" ], "3-5 Tage" ]
    ]
  },
  {
    email: "mattekaffi@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Timo Nyffenegger",
    business_name: "Mattekaffi Roesterei",
    phone: "+41 31 331 09 15",
    address: "Mattenenge 5\n3011 Bern",
    categories: [ "Essen & Trinken", "Einzelhandel" ],
    tags: [ "Kaffee", "Matte", "Roesterei" ],
    website: "https://erster-advent-bern.ch/mattekaffi",
    instagram: "https://instagram.com/mattekaffi",
    map_query: "Mattenenge 5 Bern",
    image: "home/bild_4.png",
    gallery: [ "home/bild_1.png", "home/bild_3.png", "home/bild_5.png" ],
    description: "Die Mattekaffi Roesterei bringt frisch geroestete Bohnen aus dem Mattequartier in die Adventssonntage. Am Ersten Advent duftet es nach Espresso, Kardamom und warmem Gebaeck. Das Team beraet zu Mahlgrad, Zubereitung und passenden Geschenken fuer Kaffeefans.",
    specialities: [
      "Adventsroestung mit Noten von Kakao und getrockneter Pflaume",
      "Espresso-Bar vor dem Laden von 11 bis 17 Uhr",
      "Kaffee-Geschenksets mit Berner Schokolade"
    ],
    products: [
      [ "Adventsroestung Matte", "Mittelkraeftige Bohnenmischung fuer Siebtraeger und Bialetti, frisch geroestet im Mattequartier.", 17.90, [ "250 g", "500 g", "1 kg" ], "1-2 Tage" ],
      [ "Kaffee & Schoggi Box", "Geschenkbox mit Adventsroestung, dunkler Schokolade und einer kleinen Bruehanleitung.", 34.00, [ "Standard", "Mit Grusskarte" ], "2-3 Tage" ]
    ]
  },
  {
    email: "zytglogge.buch@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Judith Hofer",
    business_name: "Zytglogge Buch & Papier",
    phone: "+41 31 311 77 03",
    address: "Kramgasse 74\n3011 Bern",
    categories: [ "Einzelhandel", "Bildung" ],
    tags: [ "Buecher", "Papeterie", "Altstadt" ],
    website: "https://erster-advent-bern.ch/zytglogge-buch",
    instagram: "https://instagram.com/zytgloggebuch",
    map_query: "Kramgasse 74 Bern",
    image: "home/bild_5.png",
    gallery: [ "home/bild_2.png", "home/bild_4.png", "home/bild_7.png" ],
    description: "Zwischen Zytglogge und Rathaus fuehrt Zytglogge Buch & Papier eine persoenliche Auswahl an Literatur, Karten, Kalendern und Schreibwaren. Fuer den Ersten Advent stellt das Team Berner Geschenkempfehlungen, Wintergeschichten und kleine Papierwaren aus regionalen Druckereien zusammen.",
    specialities: [
      "Buchberatung fuer Weihnachtsgeschenke ohne Termin",
      "Berner Adventskarten aus Risographie-Druck",
      "Kinder-Vorlesezeit um 14 Uhr"
    ],
    products: [
      [ "Berner Adventskarten Set", "Sechs illustrierte Karten mit Motiven aus der Unteren Altstadt, gedruckt auf Recyclingpapier.", 19.00, [ "6er Set" ], "Sofort abholbereit" ],
      [ "Winterlesen Paket", "Sorgfaeltig kuratiertes Buchpaket mit einem Roman, Tee und Lesezeichen.", 42.00, [ "Leise", "Spannend", "Familie" ], "2-3 Tage" ]
    ]
  },
  {
    email: "muenzplatz.blueten@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Eliane Ruch",
    business_name: "Muenzplatz Blueten",
    phone: "+41 31 311 42 90",
    address: "Muenzplatz 3\n3011 Bern",
    categories: [ "Dekoration", "Handgemachte Waren" ],
    tags: [ "Floristik", "Kraenze", "Muenzplatz" ],
    website: "https://erster-advent-bern.ch/muenzplatz-blueten",
    instagram: "https://instagram.com/muenzplatzblueten",
    map_query: "Muenzplatz 3 Bern",
    image: "home/bild_6.png",
    gallery: [ "home/bild_1.png", "home/bild_5.png", "home/bild_7.png" ],
    description: "Muenzplatz Blueten bindet saisonale Kraenze, Trockenblumen und kleine Tischdekorationen mit viel Gespuer fuer Farbe. Zum Ersten Advent stehen Tannengrund, Beeren, Eukalyptus und Kerzen bereit. Viele Stuecke entstehen direkt am Stand und koennen nach Wunsch angepasst werden.",
    specialities: [
      "Adventskranz-Bar mit frei waehlbaren Kerzenfarben",
      "Mini-Kraenze fuer Tueren, Fenster und kleine Tische",
      "Materialien aus Schweizer Gärtnereien, wenn verfuegbar"
    ],
    products: [
      [ "Muenzplatz Adventskranz", "Handgebundener Kranz mit Tanne, Eukalyptus, Beeren und vier Kerzen in warmen Naturtoenen.", 68.00, [ "Klein", "Mittel", "Gross" ], "2-4 Tage" ],
      [ "Lauben Mini-Kranz", "Kleiner Trockenblumenkranz fuer Fenster, Tueren oder Geschenkverpackungen.", 24.00, [ "Natur", "Rot", "Gruen" ], "Sofort abholbereit" ]
    ]
  },
  {
    email: "rathausplatz.schoggi@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Pascal Wenger",
    business_name: "Rathausplatz Schoggi",
    phone: "+41 31 312 66 02",
    address: "Rathausplatz 8\n3011 Bern",
    categories: [ "Süßwaren", "Essen & Trinken" ],
    tags: [ "Schokolade", "Pralinen", "Geschenke" ],
    website: "https://erster-advent-bern.ch/rathausplatz-schoggi",
    instagram: "https://instagram.com/rathausplatzschoggi",
    map_query: "Rathausplatz 8 Bern",
    image: "home/bild_7.png",
    gallery: [ "home/bild_2.png", "home/bild_3.png", "home/bild_6.png" ],
    description: "Rathausplatz Schoggi produziert Pralinen, Bruchschokolade und kleine Tafeln mit Berner Motiven. Die Adventsedition kombiniert dunkle Schokolade, Haselnuesse, Gewuerze und getrocknete Fruechte. Am Ersten Advent gibt es Degustationen und frisch verpackte Geschenkboxen.",
    specialities: [
      "Degustation der Adventspralinen im Laden",
      "Schoggi-Tafeln mit Zytglogge-Praegung",
      "Geschenkboxen werden vor Ort von Hand beschriftet"
    ],
    products: [
      [ "Zytglogge Schoggitaler", "Runde Schokoladentaler mit Zytglogge-Motiv, verpackt in einer kleinen Berner Geschenkbox.", 16.50, [ "Milch", "Dunkel", "Gemischt" ], "Sofort abholbereit" ],
      [ "Rathausplatz Pralinen", "Zwölf handgemachte Pralinen mit winterlichen Fuellungen wie Haselnuss, Orange und Gewuerzcaramel.", 29.00, [ "12er Box", "24er Box" ], "1-2 Tage" ]
    ]
  },
  {
    email: "nydegg.klang@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Reto Ammann",
    business_name: "Nydegg Klangatelier",
    phone: "+41 31 332 30 18",
    address: "Nydeggstalden 2\n3011 Bern",
    categories: [ "Unterhaltung", "Handgemachte Waren" ],
    tags: [ "Musik", "Instrumente", "Nydegg" ],
    website: "https://erster-advent-bern.ch/nydegg-klang",
    instagram: "https://instagram.com/nydeggklang",
    map_query: "Nydeggstalden 2 Bern",
    image: "home/bild_1.png",
    gallery: [ "home/bild_4.png", "home/bild_5.png", "home/bild_7.png" ],
    description: "Das Nydegg Klangatelier repariert Instrumente, baut kleine Klangobjekte und organisiert Musikmomente im Quartier. Am Ersten Advent treten befreundete Musikerinnen in kurzen Sets auf. Dazu gibt es handgemachte Rasseln, Glocken und kleine Instrumente fuer Kinder.",
    specialities: [
      "Akustische Kurzkonzerte jeweils zur vollen Stunde",
      "Klangobjekte aus Holz, Messing und Fundstuecken",
      "Instrumenten-Check fuer mitgebrachte Gitarren und Geigen"
    ],
    products: [
      [ "Nydegg Klangstern", "Kleines handgefertigtes Klangobjekt aus Holz und Messing, zum Aufhaengen oder Verschenken.", 32.00, [ "Hell", "Warm", "Tief" ], "3-5 Tage" ],
      [ "Kinder-Rhythmusset", "Ein kleines Set mit Rassel, Schellenband und Spielkarte fuer gemeinsame Adventslieder.", 26.00, [ "Set" ], "Sofort abholbereit" ]
    ]
  },
  {
    email: "junkerngass.mode@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Anouk Reber",
    business_name: "Junkerngass Mode",
    phone: "+41 31 311 83 21",
    address: "Junkerngasse 31\n3011 Bern",
    categories: [ "Mode", "Einzelhandel" ],
    tags: [ "Mode", "Textilien", "Junkerngasse" ],
    website: "https://erster-advent-bern.ch/junkerngass-mode",
    instagram: "https://instagram.com/junkerngassmode",
    map_query: "Junkerngasse 31 Bern",
    image: "home/bild_2.png",
    gallery: [ "home/bild_3.png", "home/bild_5.png", "home/bild_7.png" ],
    description: "Junkerngass Mode fuehrt kleine Labels, warme Strickteile und langlebige Accessoires fuer die Winterzeit. Am Ersten Advent legt das Team den Fokus auf faire Materialien, ruhige Farben und Geschenke, die lange getragen werden. Besucherinnen koennen Schals, Muetzen und Jacken direkt kombinieren und reservieren.",
    specialities: [
      "Winterstyling-Beratung ohne Termin von 11 bis 17 Uhr",
      "Limitierte Schalserie aus Schweizer Wolle",
      "Geschenkverpackung mit Stoffband statt Einwegpapier"
    ],
    products: [
      [ "Junkerngass Wollschal", "Weicher Schal aus mulesingfreier Wolle in gedeckten Winterfarben, gefertigt in kleiner Serie.", 89.00, [ "Salbei", "Sand", "Nachtblau" ], "2-3 Tage" ],
      [ "Altstadt Muetze", "Schlichte Rippenmuetze aus warmer Merinowolle, passend fuer kalte Spaziergaenge durch die Lauben.", 48.00, [ "S/M", "M/L" ], "Sofort abholbereit" ]
    ]
  },
  {
    email: "kramgass.spiel@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "David Luthi",
    business_name: "Kramgass Spielwaren",
    phone: "+41 31 312 09 41",
    address: "Kramgasse 22\n3011 Bern",
    categories: [ "Spielwaren", "Einzelhandel" ],
    tags: [ "Kinder", "Spiele", "Kramgasse" ],
    website: "https://erster-advent-bern.ch/kramgass-spielwaren",
    instagram: "https://instagram.com/kramgassspielwaren",
    map_query: "Kramgasse 22 Bern",
    image: "home/bild_5.png",
    gallery: [ "home/bild_1.png", "home/bild_4.png", "home/bild_6.png" ],
    description: "Kramgass Spielwaren sammelt Holzspielzeug, Kartenspiele, Puzzles und kleine Entdeckungen fuer Kinder und Familien. Zum Ersten Advent entstehen im Laden kurze Spielrunden, Empfehlungen fuer verschiedene Altersstufen und ein Packtisch fuer Geschenke, die sofort unter den Baum koennen.",
    specialities: [
      "Spielberatung nach Alter und Gruppengroesse",
      "Offene Puzzle- und Kartenrunde im Laden",
      "Kleine Wichtelgeschenke unter 20 Franken"
    ],
    products: [
      [ "Berner Lauben Puzzle", "Illustriertes 500-Teile-Puzzle mit Motiven der Unteren Altstadt und kleinen Adventsdetails.", 27.50, [ "500 Teile" ], "Sofort abholbereit" ],
      [ "Familienkarten Advent", "Schnelles Kartenspiel fuer Familienabende mit einfachen Regeln und winterlichen Berner Motiven.", 18.00, [ "Standard" ], "1-2 Tage" ]
    ]
  },
  {
    email: "gerechtigkeitsgass.design@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Noemi Schmid",
    business_name: "Gerechtigkeitsgass Design",
    phone: "+41 31 311 64 55",
    address: "Gerechtigkeitsgasse 19\n3011 Bern",
    categories: [ "Design", "Dekoration" ],
    tags: [ "Design", "Wohnaccessoires", "Geschenke" ],
    website: "https://erster-advent-bern.ch/gerechtigkeitsgass-design",
    instagram: "https://instagram.com/gerechtigkeitsgassdesign",
    map_query: "Gerechtigkeitsgasse 19 Bern",
    image: "home/bild_6.png",
    gallery: [ "home/bild_2.png", "home/bild_4.png", "home/bild_7.png" ],
    description: "Gerechtigkeitsgass Design kuratiert Wohnaccessoires, Leuchten, Textilien und kleine Objekte von unabhaengigen Gestalterinnen. Am Ersten Advent zeigt der Laden Tischideen fuer Winteressen, reduzierte Dekoration und Geschenke fuer Menschen, die klare Formen moegen.",
    specialities: [
      "Tischdekorationen fuer Adventsessen zum Mitnehmen",
      "Designberatung fuer kleine Wohnungen und Schaufenster",
      "Limitierte Kerzenstaender aus pulverbeschichtetem Metall"
    ],
    products: [
      [ "Sandstein Kerzenstaender", "Reduzierter Kerzenstaender aus Metall in warmem Sandsteinton, inspiriert von Berner Fassaden.", 44.00, [ "Einzeln", "2er Set" ], "2-3 Tage" ],
      [ "Gerechtigkeitsgass Tablett", "Flaches Serviertablett aus geformtem Holz fuer Kaffee, Gebaeck oder Adventslicht.", 62.00, [ "Natur", "Schwarz" ], "3-5 Tage" ]
    ]
  },
  {
    email: "brunngass.atelier@erster-advent-bern.ch",
    password: "bern-seed-2026",
    owner: "Selina Baumann",
    business_name: "Brunngass Atelier",
    phone: "+41 31 311 58 12",
    address: "Brunngasse 9\n3011 Bern",
    categories: [ "Handgemachte Waren", "Einzelhandel" ],
    tags: [ "Atelier", "Keramik", "Papier" ],
    website: "https://erster-advent-bern.ch/brunngass-atelier",
    instagram: "https://instagram.com/brunngassatelier",
    map_query: "Brunngasse 9 Bern",
    image: nil,
    gallery: [],
    description: "Das Brunngass Atelier ist ein bewusst schlicht gehaltener Seed-Store ohne Bildmaterial. Es zeigt, wie die Store-Uebersicht und Detailseite aussehen, wenn ein teilnehmendes Geschaeft noch keine Fotos hochgeladen hat. Inhaltlich steht das Atelier fuer kleine Keramikserien, Papierobjekte und ruhige Geschenkideen aus der Unteren Altstadt.",
    specialities: [
      "Seed-Beispiel ohne Store-Bilder fuer den Platzhalter-Test",
      "Kleine Keramikschalen und Karten in limitierten Serien",
      "Persoenliche Beratung fuer reduzierte Adventsgeschenke"
    ],
    products: [
      [ "Brunngass Keramikschale", "Kleine handgeformte Schale aus heller Keramik, ideal fuer Schmuck, Salz oder Adventsnuesse.", 36.00, [ "Klein", "Mittel" ], "4-6 Tage" ],
      [ "Papierlicht Set", "Gefaltete Papierlichter mit feiner Lochstruktur fuer LED-Teelichter und Fensterbaenke.", 22.00, [ "3er Set", "6er Set" ], "2-3 Tage" ]
    ]
  }
]

businesses.each.with_index do |seed, index|
  user = confirmed_user!(
    email: seed.fetch(:email),
    password: seed.fetch(:password),
    role: 0,
    name: seed.fetch(:owner),
    business_name: seed.fetch(:business_name),
    address: seed.fetch(:address),
    phone: seed.fetch(:phone),
    category: seed.fetch(:categories).first,
    package_plan: index.even? ? 2 : 1,
    is_verified: true,
    payment_method: "bank_transfer"
  )

  business = user.create_business!(
    business_name: seed.fetch(:business_name),
    phone: seed.fetch(:phone),
    address: seed.fetch(:address),
    billing_address: seed.fetch(:address),
    contact_name: seed.fetch(:owner),
    email: seed.fetch(:email),
    website: seed.fetch(:website),
    instagram: seed.fetch(:instagram),
    tiktok: "",
    linkedin: "",
    facebook: "",
    map_link: "https://maps.google.com/?q=#{ERB::Util.url_encode(seed.fetch(:map_query))}",
    description: seed.fetch(:description),
    first_advent_specialities: "<ul>#{seed.fetch(:specialities).map { |item| "<li>#{ERB::Util.html_escape(item)}</li>" }.join}</ul>",
    tags: seed.fetch(:tags),
    categories: seed.fetch(:categories),
    confirmed: true,
    status: :confirmed
  )

  attach_asset!(business, :main_image, seed.fetch(:image)) if seed.fetch(:image).present?
  seed.fetch(:gallery).each.with_index(1) do |filename, gallery_index|
    attach_asset!(business, "image_gallery#{gallery_index}", filename)
  end

  Payment.create!(
    user: user,
    payment_image: "seeded-bank-transfer-#{user.id}.pdf",
    payment_session_id: "seed_bern_#{user.id}",
    customer_email: user.email,
    plan: index.even? ? "Vereinsmitglied Plus" : "Vereinsmitglied Basis",
    is_verified: index == 7 ? "Pending" : "approved"
  )

  seed.fetch(:products).each.with_index do |product_seed, product_index|
    title, description, price, sizes, delivery_time = product_seed
    image_number = ((index + product_index) % 7) + 1

    Product.create!(
      user: user,
      title: title,
      description: description,
      price: price,
      main_product_image: ActionController::Base.helpers.asset_path("home/bild_#{image_number}.png"),
      images_of_product: [
        ActionController::Base.helpers.asset_path("home/bild_#{(image_number % 7) + 1}.png"),
        ActionController::Base.helpers.asset_path("home/bild_#{((image_number + 1) % 7) + 1}.png")
      ],
      sizes: sizes,
      delievry_time: delivery_time,
      total_orders: 0
    )
  end
end

customers = [
  [ "Sophie Keller", "sophie.keller@example.ch", "Munstergasse 18\n3011 Bern", "+41 79 441 12 09" ],
  [ "Andrin Gerber", "andrin.gerber@example.ch", "Brunngasse 7\n3011 Bern", "+41 78 820 31 14" ],
  [ "Nora Aebi", "nora.aebi@example.ch", "Junkerngasse 21\n3011 Bern", "+41 76 335 44 91" ],
  [ "Luca Marti", "luca.marti@example.ch", "Laenggasse 40\n3012 Bern", "+41 77 612 08 52" ]
].map do |name, email, address, phone|
  confirmed_user!(
    email: email,
    password: "bern-customer-2026",
    role: 0,
    name: name,
    address: address,
    phone: phone,
    category: "Besucherinnen und Besucher"
  )
end

products = Product.order(:created_at).to_a
order_statuses = [ "accepted", "pending", "packed", "ready_for_pickup" ]

products.first(14).each.with_index do |product, index|
  customer = customers[index % customers.length]
  size = product.size_options[index % product.size_options.length]
  quantity = (index % 3) + 1

  Order.create!(
    product: product,
    customer: customer,
    quantity: quantity,
    size: size,
    order_no: "EA-BE-#{Time.current.year}-#{(index + 1).to_s.rjust(4, "0")}",
    accept_order: order_statuses[index % order_statuses.length],
    created_at: (index + 1).days.ago,
    updated_at: (index + 1).days.ago
  )

  product.increment!(:total_orders, quantity)
end

SiteSetting.create!(brand_color: SiteSetting::DEFAULT_BRAND_COLOR)

# ---------------------------------------------------------------------------
# Frontpage CMS
#
# Mirrors the content the homepage shipped with before it became editable, so
# a freshly seeded database renders the designed page 1:1.
# ---------------------------------------------------------------------------

sections = [
  {
    block_type: :text_image_block,
    image: "bild_6.png",
    image_position: "left",
    title: "<div><strong>Informationen</strong><br>für Besucherinnen und Besucher</div>",
    content: "<div>Die Untere Altstadt umfasst das in der idyllischen Aareschlaufe " \
             "eingebettete Gebiet vom Matte-Quartier bis zum Zytglogge. Im Gegensatz " \
             "zur Oberen Altstadt finden sich hier noch zahlreiche unabhängige und " \
             "eingesessene Geschäfte, Ateliers, Buchhandlungen, Handwerksbetriebe und " \
             "Galerien. Wer einzigartige Kleidungsstücke, in Bern hergestellten Schmuck " \
             "oder eine liebevoll sortierte Buchhandlung und Objekte mit Geschichte " \
             "schätzt, wird beim Schlendern durch die historischen Lauben sicherlich " \
             "fündig.</div>",
    button_text: "Teilnehmende Geschäfte entdecken",
    button_url: "/stores"
  },
  {
    block_type: :text_image_block,
    image: "bild_6.png",
    image_position: "right",
    title: "<div><strong>Informationen</strong> für Geschäfte und Gastronomiebetriebe</div>",
    content: "<div>Die Aufforderung zur Anmeldung wird wie üblich nach den Sommerferien " \
             "verschickt. Bitte registrieren Sie sich über das Kontaktformular für den " \
             "Verteiler. Geschäfte der Unteren Altstadt beteiligen sich mit einem " \
             "pauschalen Teilnahmebeitrag von CHF 200. Aus damit zur Verfügung stehenden " \
             "Budget wird der Anlass weit über die Stadtgrenzen hinaus beworben. Zudem " \
             "werden damit auch attraktive Rahmenprogramme finanziert und gefördert.</div>",
    button_text: "Jetzt mein Geschäft anmelden",
    button_url: "/users/sign_in"
  },
  {
    block_type: :full_image_block,
    image: "bild_7.png"
  },
  {
    block_type: :plain_text_block,
    title: "<div><em>Über den</em><br>Verein Erster Advent</div>",
    content: "<div>Der Erste Advent ist ein Anlass, der seit 30 Jahren Tradition hat, mit " \
             "seinem Ursprung an der beschaulichen Postgasse. Benachbarte Ladengeschäfte " \
             "schlossen sich zusammen, um am Ersten Advent gemeinsam den Besucherinnen und " \
             "Besuchern auch die weniger frequentierten Gassen näherzubringen. Das Konzept " \
             "wird mittlerweile von der gesamten Unteren Altstadt getragen und durch den " \
             "Mitgliederbeitrag eines jeden einzelnen Geschäftes gestützt.</div>"
  }
]

sections.each.with_index(1) do |attributes, position|
  image = attributes.delete(:image)
  block = CmsBlock.new(attributes.merge(page: "home", position: position, is_active: true))

  attach_asset!(block, :image, "home/#{image}") if image

  block.save!
end

[
  [ "Kommt #{Date.today.year} auch wieder der Samichlous?", "" ],
  [ "Haben alle Geschäfte geöffnet?", "" ],
  [ "Finden andere Rahmenveranstaltungen statt?", "" ],
  [ "Wie finanziert sich die Organisation?", "" ],
  [ "Findet wieder das Adventssingen auf der Kramgasse statt?", "" ]
].each.with_index(sections.length + 1) do |(question, answer), position|
  CmsBlock.create!(
    page: "home",
    position: position,
    block_type: :faq_item,
    is_active: true,
    question: question,
    answer: answer
  )
end

puts "Brand colour: #{SiteSetting.current.brand_color}"
puts "Seeded #{User.count} users, #{Business.count} Bern stores, #{Product.count} products, #{Order.count} orders, #{Payment.count} payments and #{CmsBlock.count} CMS blocks."
