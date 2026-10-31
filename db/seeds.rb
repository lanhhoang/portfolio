# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

if Rails.env.development?
  require "base64"
  require "stringio"

  # find_or_initialize_by queries outside the loaded association, so autosave
  # would skip edits to existing rows; look the row up in memory instead.
  translation_for = lambda do |record, locale|
    record.translations.find { |item| item.locale == locale } || record.translations.build(locale: locale)
  end

  translations = {
    "en" => {
      profile: [ "Demo Designer", "Ideas. Interfaces. Impact.", "A neutral demonstration profile.", "## About\n\nThis content is safe to replace.", "Available", "Product engineer" ],
      tag: [ "Ruby", "ruby" ],
      project: [ "Sample System", "sample-system", "A database-backed demonstration project.", "## Result\n\nA small, useful result.", "Designer and engineer" ],
      post: [ "A Sample Technical Note", "sample-technical-note", "A short demonstration article.", "## Note\n\n```ruby\nputs :hello\n```" ],
      resume: [ "Demo Résumé", "A localized demonstration résumé." ]
    },
    "fr" => {
      profile: [ "Designer Démo", "Idées. Interfaces. Impact.", "Un profil de démonstration neutre.", "## À propos\n\nCe contenu peut être remplacé.", "Disponible", "Ingénieur produit" ],
      tag: [ "Ruby", "ruby-fr" ],
      project: [ "Système exemple", "systeme-exemple", "Un projet de démonstration stocké en base.", "## Résultat\n\nUn résultat simple et utile.", "Designer et ingénieur" ],
      post: [ "Une note technique", "note-technique", "Un court article de démonstration.", "## Note\n\n```ruby\nputs :bonjour\n```" ],
      resume: [ "CV de démonstration", "Un CV de démonstration localisé." ]
    },
    "vi" => {
      profile: [ "Nhà thiết kế mẫu", "Ý tưởng. Giao diện. Tác động.", "Hồ sơ minh họa trung lập.", "## Giới thiệu\n\nNội dung này có thể được thay thế.", "Sẵn sàng", "Kỹ sư sản phẩm" ],
      tag: [ "Ruby", "ruby-vi" ],
      project: [ "Hệ thống mẫu", "he-thong-mau", "Dự án minh họa được lưu trong cơ sở dữ liệu.", "## Kết quả\n\nMột kết quả nhỏ và hữu ích.", "Nhà thiết kế và kỹ sư" ],
      post: [ "Ghi chú kỹ thuật mẫu", "ghi-chu-ky-thuat-mau", "Một bài viết minh họa ngắn.", "## Ghi chú\n\n```ruby\nputs :xin_chao\n```" ],
      resume: [ "Hồ sơ mẫu", "Hồ sơ minh họa đã được bản địa hóa." ]
    }
  }

  profile = Profile.find_or_initialize_by(singleton_guard: 1)
  profile.assign_attributes(
    public_contact_email: "owner@example.test",
    social_links: { "GitHub" => "https://github.com/example" },
    accent: "lime"
  )
  translations.each do |locale, copy|
    item = translation_for.call(profile, locale)
    item.assign_attributes(
      display_name: copy[:profile][0], headline: copy[:profile][1],
      introduction: copy[:profile][2], biography_markdown: copy[:profile][3],
      availability_label: copy[:profile][4], job_title: copy[:profile][5]
    )
  end
  profile.save!

  tag = TagTranslation.find_by(locale: "en", slug: "ruby")&.tag || Tag.new
  translations.each do |locale, copy|
    item = translation_for.call(tag, locale)
    item.assign_attributes(name: copy[:tag][0], slug: copy[:tag][1])
  end
  tag.save!

  project = ProjectTranslation.find_by(locale: "en", slug: "sample-system")&.project || Project.new
  project.assign_attributes(
    started_on: Date.new(2026, 1, 1),
    ended_on: Date.new(2026, 6, 30), source_url: "https://github.com/example/sample-system",
    featured_position: 1
  )
  translations.each do |locale, copy|
    item = translation_for.call(project, locale)
    item.assign_attributes(
      title: copy[:project][0], slug: copy[:project][1], summary: copy[:project][2], role: copy[:project][4],
      body_markdown: copy[:project][3], state: "published", published_at: Time.zone.parse("2026-07-01 09:00")
    )
    # The fr/vi publication validation reads persisted rows, so save the
    # published English translation before assigning the other locales.
    project.save! if locale == "en"
  end
  project.save!
  project.tags << tag unless project.tags.exists?(tag.id)

  post = PostTranslation.find_by(locale: "en", slug: "sample-technical-note")&.post || Post.new
  translations.each do |locale, copy|
    item = translation_for.call(post, locale)
    item.assign_attributes(
      title: copy[:post][0], slug: copy[:post][1], excerpt: copy[:post][2],
      body_markdown: copy[:post][3], state: "published", published_at: Time.zone.parse("2026-08-01 09:00")
    )
    # Same two-pass save as the project: English must be persisted first.
    post.save! if locale == "en"
  end
  post.save!
  post.tags << tag unless post.tags.exists?(tag.id)

  resume = Resume.find_or_initialize_by(singleton_guard: 1)
  resume.updated_on = Date.new(2026, 9, 2)
  translations.each do |locale, copy|
    item = translation_for.call(resume, locale)
    item.assign_attributes(title: copy[:resume][0], description: copy[:resume][1])
  end
  resume.save!

  png = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )
  attach_png = lambda do |record, name, filename|
    attachment = record.public_send(name)
    attachment.attach(io: StringIO.new(png), filename: filename, content_type: "image/png") unless attachment.attached?
  end
  attach_png.call(profile, :portrait, "demo-portrait.png")
  attach_png.call(project, :cover_image, "demo-project.png")
  attach_png.call(post, :cover_image, "demo-post.png")

  resume.translations.each do |translation|
    next if translation.pdf.attached?

    pdf = "%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n"
    translation.pdf.attach(
      io: StringIO.new(pdf), filename: "demo-resume-#{translation.locale}.pdf",
      content_type: "application/pdf"
    )
  end

  puts "Seeded localized demo profile, tag, project, post, résumé, and attachments."
else
  puts "Development demo seeds skipped in #{Rails.env}."
end
