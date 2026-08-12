# Konzept

Dieses Dokument beschreibt den geplanten Ablauf für die Abwicklung der Geschäfte und Produkte am ersten Advent.

## Bestehend: Registrierung & Freigabe der Geschäfte

Dieser Teil ist bereits fertig gebaut und im System live. Er dient hier als Grundlage, damit klar ist, worauf die neuen Flows aufbauen.

1. **Registrierung durch das Geschäft**
   Ein Geschäft registriert sich selbst über ein öffentliches Formular (Name, Adresse, Telefon, Kategorie, Kontaktperson). Danach kann es sich einloggen, hat aber noch keinen bestätigten Status.
2. **Warteliste im Admin-Bereich**
   Unter "Stores" sieht der Admin alle registrierten Geschäfte in einer durchsuchbaren Liste (Suche nach Name).
3. **Detailprüfung**
   Der Admin öffnet ein einzelnes Geschäft und sieht dort alle hinterlegten Angaben sowie die hochgeladenen Bilder (Hauptbild, Galeriebilder).
4. **Statusentscheid**
   Der Admin bestätigt dann die neu erstellten Geschäft. Der Admin setzt den Status manuell über ein Auswahlfeld: _ausstehend_ (Standard nach Registrierung), _bestätigt_, _abgelehnt_ oder _gelöscht_. Erst mit Status "bestätigt" ist ein Geschäft im Frontend als aktiver Store sichtbar.

   Zu beachten: Aktuell wird das Geschäft bei einer Statusänderung **nicht automatisch per E-Mail benachrichtigt** — das müsste bei Bedarf noch ergänzt werden (siehe Fragen).

## Geplanter Flow für Admin (Printprodukte)

1. **Produkte verwalten**
   Der Admin legt Produkte im Sortiment an (Titel, Beschreibung, Preis, Bild, Lieferzeit) und kann sie bearbeiten oder entfernen. Geschäfte legen selbst keine Produkte mehr an.
2. **Bestellungen einsehen**
   Der Admin sieht alle eingehenden Bestellungen in einer Übersicht: welches Geschäft, welches Produkt, Menge, Status, ob bezahlt.
3. **Zahlungsbeleg prüfen**
   Sobald ein Geschäft eine Bestellung aufgibt, lädt es einen Screenshot/Beleg der Zahlung hoch. Der Admin sieht diese Belege in einer Warteliste ("offene Zahlungsprüfungen") und bestätigt oder lehnt sie ab. (Siehe auch Fragen zu diesem Flow).
4. **Bestellstatus setzen**
   Nach Zahlungsbestätigung wechselt der Admin den Status manuell weiter, z. B. von _erstellt_ → _bezahlt_ → _versendet_, sobald die Ware das Haus verlässt.

## Geplanter Flow für Geschäfte (Printprodukte)

1. Ein registriertes und bestätigtes Geschäft sieht das Produktesortiment des Veranstalters.
2. Es wählt ein Produkt, gibt die gewünschte Menge/Grösse an und schliesst die Bestellung ab.
3. Nach der Bestellung erhält es eine Zahlungsaufforderung (Rechnung per E-Mail, mit den Zahlungsdetails/Referenz).
4. Nach der Überweisung lädt das Geschäft einen Screenshot/Beleg der Zahlung im System hoch. (Siehe auch Fragen dazu)
5. Das Geschäft sieht in seiner eigenen Übersicht ("Meine Bestellungen") jederzeit den aktuellen Status: erstellt, bezahlt, versendet.

→ Mails können nach bedarf versendet werden, damit die Geschäfte informiert sind.

## CMS

Der Admin kann Inhalte der Startseite selbst pflegen: Textblöcke, Bilder und FAQ-Einträge, jeweils in einer definierten Reihenfolge an- und ausschaltbar.

## Rollenkonzept

Es gibt drei Rollen:

- User (Für die Geschäfte, sie sehen nur ihr eigenes geschäft)
- Admin (Für Admins, können Geschäfte bestätigen / Produkte und Bestellungen verwalten)
- Superadmin (Kann zudem andere Admins hinzufügen)

## Fragen

Nur Punkte, bei denen wir ohne Antwort des Kunden keine sinnvolle Umsetzungsentscheidung treffen können:

1. **Zahlungen:** Der oben beschriebene Screenshot-Flow ist der pragmatischste Start, aber technisch könnten wir auch andere Methoden versuchen:

- Onlinezahlung
- Upload von Banktransaktionen durch Admin für den Abgleich.
  Was ist hier eure Meinung dazu?

2. **Rechnungsnummer:** Braucht die Rechnung eine fortlaufende, buchhaltungskonforme Rechnungsnummer, oder reicht eine interne Referenz?
