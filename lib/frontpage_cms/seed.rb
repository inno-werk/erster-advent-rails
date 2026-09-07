module FrontpageCms
  class Seed
    SECTIONS = [
      {
        block_type: :text_image_block,
        image: "bild_6.png",
        image_position: "left",
        title: "<div><strong>Informationen</strong><br>für Besucherinnen und Besucher</div>",
        content: "<div>Die Untere Altstadt umfasst das in der idyllischen Aareschlaufe eingebettete Gebiet vom " \
                 "Matte-Quartier bis zum Zytglogge. Im Gegensatz zur Oberen Altstadt finden sich hier noch " \
                 "zahlreiche unabhängige und eingesessene Geschäfte, Ateliers, Buchhandlungen, Handwerksbetriebe " \
                 "und Galerien. Wer einzigartige Kleidungsstücke, in Bern hergestellten Schmuck oder eine liebevoll " \
                 "sortierte Buchhandlung und Objekte mit Geschichte schätzt, wird beim Schlendern durch die " \
                 "historischen Lauben sicherlich fündig.</div>",
        button_text: "Teilnehmende Geschäfte entdecken",
        button_url: "/stores"
      },
      {
        block_type: :text_image_block,
        image: "bild_6.png",
        image_position: "right",
        title: "<div><strong>Informationen</strong> für Geschäfte und Gastronomiebetriebe</div>",
        content: "<div>Die Aufforderung zur Anmeldung wird wie üblich nach den Sommerferien verschickt. Bitte " \
                 "registrieren Sie sich über das Kontaktformular für den Verteiler. Geschäfte der Unteren Altstadt " \
                 "beteiligen sich mit einem pauschalen Teilnahmebeitrag von CHF 200. Aus damit zur Verfügung " \
                 "stehenden Budget wird der Anlass weit über die Stadtgrenzen hinaus beworben. Zudem werden damit " \
                 "auch attraktive Rahmenprogramme finanziert und gefördert.</div>",
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
        content: "<div>Der Erste Advent ist ein Anlass, der seit 30 Jahren Tradition hat, mit seinem Ursprung an der " \
                 "beschaulichen Postgasse. Benachbarte Ladengeschäfte schlossen sich zusammen, um am Ersten Advent " \
                 "gemeinsam den Besucherinnen und Besuchern auch die weniger frequentierten Gassen " \
                 "näherzubringen. Das Konzept wird mittlerweile von der gesamten Unteren Altstadt getragen und " \
                 "durch den Mitgliederbeitrag eines jeden einzelnen Geschäftes gestützt.</div>"
      }
    ].freeze

    FAQS = [
      [
        "Findet wieder das Adventssingen auf der Kramgasse statt?",
        "Das beliebte Adventssingen ist auch in diesem Jahr wieder vorgesehen. Lauschen Sie dem Chor ab 16.00 Uhr " \
          "auf der Kramgasse auf der Höhe des Münstergässchens. Wir bedanken uns beim Kramgassleist für die " \
          "Organisation und Finanzierung dieses beliebten Programmpunkts."
      ],
      [
        "Kommt #{EventConfiguration.year} auch wieder der Samichlous?",
        "Der Samichlous kommt auch in diesem Jahr wieder in die Gassen der Unteren Altstadt. Er ist um 16.45 Uhr " \
          "beim Zytglogge anzutreffen. Wir bedanken uns beim Kramgassleist und der Samichlousenzunft für die " \
          "Organisation und Finanzierung dieses beliebten Programmpunkts."
      ],
      [
        "Haben alle Geschäfte geöffnet?",
        "Leider nicht. Die Teilnahme am Anlass und das Bezahlen der Teilnahmegebühr sind freiwillig. Für die " \
          "Geschäfte besteht kein Teilnahmezwang und das Öffnen des Geschäfts ist auch unabhängig von der offiziellen " \
          "Teilnahme gestattet. Es ist im Sinne des für die Altstadt typischen und erhaltenswerten Zusammenhalts, " \
          "dass möglichst viele Lokale zusammenspannen, damit die Besucherfrequenzen in der Adventszeit auch in der " \
          "Unteren Altstadt steigen."
      ],
      [
        "Finden andere Rahmenveranstaltungen statt?",
        "Die Geschäfte kreieren an diesem Tag oft ihr eigenes abwechslungsreiches Rahmenprogramm, das von " \
          "inspirierenden Lesungen über kreative Workshops bis hin zu aussergewöhnlichen Events reicht. Darüber " \
          "hinaus haben einige Läden ganz besondere Highlights im Angebot: Exklusive Produkte oder limitierte " \
          "Editionen, die nur an diesem speziellen Tag verfügbar sind und so ein einzigartiges Einkaufserlebnis " \
          "versprechen."
      ],
      [
        "Wie finanziert sich die Organisation?",
        "Seit der Ersten Durchführung 1993 beteiligen sich die teilnehmenden Geschäfte mit einem Beitrag von CHF 200. " \
          "Damit wird insbesondere die koordinierte Kommunikation und die Erstellung sowie Produktion von Werbe- " \
          "und Informationsmaterial finanziert. Darunter gehören unter anderem der Druck von Postkarten und Plakaten, " \
          "der Unterhalt der Webseite, die Kosten für die Schaltung von Anzeigen und Plakataushängen in und um die " \
          "Stadt Bern wie auch die Führung und Verwaltung aller Anmeldungen, das Verteilen der Postkarten und die " \
          "Sicherstellung von Sponsorengeldern."
      ]
    ].freeze

    def self.call
      return CmsBlock.for_page("home").ordered.to_a if CmsBlock.for_page("home").exists?

      blobs = upload_images
      begin
        ApplicationRecord.transaction do
          create_sections(blobs)
          create_faqs
        end
      rescue StandardError
        blobs.each_value(&:purge)
        raise
      end

      CmsBlock.for_page("home").ordered.to_a
    end

    def self.upload_images
      blobs = {}
      SECTIONS.filter_map { |section| section[:image] }.uniq.each do |filename|
        path = Rails.root.join("app/assets/images/home", filename)
        io = StringIO.new(path.binread)
        blobs[filename] = ActiveStorage::Blob.create_after_unfurling!(
          io: io, filename: filename, content_type: "image/png"
        )
        blobs.fetch(filename).upload_without_unfurling(io)
      end
      blobs
    rescue StandardError
      blobs.each_value(&:purge)
      raise
    end
    private_class_method :upload_images

    def self.create_sections(blobs)
      SECTIONS.each.with_index(1) do |attributes, position|
        image = attributes[:image]
        block = CmsBlock.new(attributes.except(:image).merge(page: "home", position: position, is_active: true))
        block.image.attach(blobs.fetch(image)) if image
        block.save!
      end
    end
    private_class_method :create_sections

    def self.create_faqs
      FAQS.each.with_index(SECTIONS.length + 1) do |(question, answer), position|
        CmsBlock.create!(
          page: "home", position: position, block_type: :faq_item, is_active: true,
          question: question, content: answer
        )
      end
    end
    private_class_method :create_faqs
  end
end
