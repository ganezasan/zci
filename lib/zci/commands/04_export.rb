desc 'Add or update localized resource files(categories, sections and articles) in Zendesk'
command :'export:translations' do |c|
  c.desc 'Directory of resource files'
  c.long_desc <<-EOS.strip_heredoc
    This is the directory where the project's files will be store.
  EOS
  c.default_value 'resources'
  c.arg_name 'dir'
  c.flag [:resources_dir]

  c.desc 'Defines in which language translations should be uploaded. By default translations are uploaded for all languages'
  c.default_value 'all'
  c.arg_name 'language_code'
  c.flag [:l, :language]

  c.action do |global_options, options, args|
    resources_dir = File.join(File.dirname(global_options[:config]), options[:resources_dir])
    language = options[:language]

    crowdin_supported_languages = @crowdin.supported_languages

    @cli_config['categories'].each do |category_section|
      zendesk_url = category_section.fetch('brand_url', @cli_config['zendesk_base_url'])

      zendesk_client = ZCI.initialize_zendesk_client(
        zendesk_url,
        @cli_config['zendesk_username'],
        @cli_config['zendesk_password'],
        global_options[:verbose]
      )

      if language == 'all'
        zendesk_locales = zendesk_client.locales
      else
        zendesk_locales = zendesk_client.locales.select { |locale| locale.locale == language }
      end

      zendesk_locales.reject(&:default?).each do |locale|
        if lang = category_section['translations'].detect { |tr| tr['zendesk_locale'].casecmp(locale.locale) == 0 }
          crowdin_locale = crowdin_supported_languages.detect { |l| l['crowdin_code'] == lang['crowdin_language_code'] }['locale']

          category_xml_files = Dir["#{resources_dir}/#{crowdin_locale}/#{category_section['zendesk_category']}/category_*.xml"]
          section_xml_files = Dir["#{resources_dir}/#{crowdin_locale}/#{category_section['zendesk_category']}/section_*.xml"]
          article_xml_files = Dir["#{resources_dir}/#{crowdin_locale}/#{category_section['zendesk_category']}/article_*.xml"]

          all_categories = []
          all_sections = []
          all_articles = []

          # Read categories from XML files
          category_xml_files.each do |file|
            category_xml_file = File.read(file)
            category_xml = parse_category_xml(category_xml_file)
            all_categories << category_xml
          end

          # Read sections from XML files
          section_xml_files.each do |file|
            section_xml_file = File.read(file)
            section_xml = parse_section_xml(section_xml_file)
            all_sections << section_xml
          end

          # Read articles from XML filse
          article_xml_files.each do |file|
            article_xml_file = File.read(file)
            article_xml = parse_article_xml(article_xml_file)
            all_articles << article_xml
          end

          ### Categories
          #
          categories = zendesk_client.hc_categories
          all_categories.each do |category_hash|
            if category = categories.find(id: category_hash[:id])
              if category_tr = category.translations.detect { |tr| tr.locale.casecmp(locale.locale) == 0 }
                category_tr.update(title: category_hash[:name], body: category_hash[:description])
                if category_tr.changed?
                  if category_tr.save
                    puts "[Zendesk] Updating `#{lang['crowdin_language_code']}` language translation for Category\##{category.id}."
                  else
                    puts "[Zendesk] Failed to update `#{lang['crowdin_language_code']}` language translation for Category\##{category.id}."
                  end
                else
                  puts "[Zendesk] Skipping `#{lang['crowdin_language_code']}` language translation for Category\##{category.id}. Already up-to-date."
                end
              else
                category_tr = category.translations.build(locale: locale.locale, title: category_hash[:name], body: category_hash[:description])
                if category_tr.save
                  puts "[Zendesk] Creating `#{lang['crowdin_language_code']}` language translation for Category\##{category.id}."
                else
                  puts "[Zendesk] Failed to create `#{lang['crowdin_language_code']}` language translation for Category\##{category.id}."
                end
              end
            end
          end

          ### Sections
          #
          sections = zendesk_client.sections
          all_sections.each do |section_hash|
            if section = sections.find(id: section_hash[:id])
              if section_tr = section.translations.detect { |tr| tr.locale.casecmp(locale.locale) == 0 }
                section_tr.update(title: section_hash[:name], body: section_hash[:description])
                if section_tr.changed?
                  if section_tr.save
                    puts "[Zendesk] Updating `#{lang['crowdin_language_code']}` language translation for Section\##{section.id}."
                  else
                    puts "[Zendesk] Failed to update `#{lang['crowdin_language_code']}` language translation for Section\##{section.id}."
                  end
                else
                  puts "[Zendesk] Skipping `#{lang['crowdin_language_code']}` language translation for Section\##{section.id}. Already up-to-date."
                end
              else
                section_tr = section.translations.build(locale: locale.locale, title: section_hash[:name], body: section_hash[:description])
                if section_tr.save
                  puts "[Zendesk] Creating `#{lang['crowdin_language_code']}` language translation for Section\##{section.id}."
                else
                  puts "[Zendesk] Failed to create `#{lang['crowdin_language_code']}` language translation for Section\##{section.id}."
                end
              end
            end
          end

          ### Articles
          #
          all_articles.each do |article_hash|
            if section = sections.find(id: article_hash[:section_id])
              if article = section.articles.find(id: article_hash[:id])
                if article_tr = article.translations.detect { |tr| tr.locale.casecmp(locale.locale) == 0 }
                  article_tr.update(title: article_hash[:title], body: article_hash[:body])
                  if article_tr.changed?
                    if article_tr.save
                      puts "[Zendesk] Updating `#{lang['crowdin_language_code']}` language translation for Article\##{article.id}."
                    else
                      puts "[Zendesk] Failed to update `#{lang['crowdin_language_code']}` language translation for Article\##{article.id}."
                    end
                  else
                    puts "[Zendesk] Skipping `#{lang['crowdin_language_code']}` language translation for Article\##{article.id}. Already up-to-date."
                  end
                else
                  article_tr = article.translations.build(locale: locale.locale, draft: true, title: article_hash[:title], body: article_hash[:body])
                  if article_tr.save
                    puts "[Zendesk] Creating `#{lang['crowdin_language_code']}` language translation for Article\##{article.id}."
                  else
                    puts "[Zendesk] Failed to create `#{lang['crowdin_language_code']}` language translation for Article\##{article.id}."
                  end
                end
              end
            end
          end

        end
      end # zendesk_locales
    end # @cli_config['categories'].each
  end
end
