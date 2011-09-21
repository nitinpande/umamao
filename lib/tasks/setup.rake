desc "Generate Jammit assets"
task :generate_assets => [:environment] do
  Jammit.package!
end

desc "Setup application"
task :bootstrap => [:environment, "setup:reset",
                    "setup:create_admin",
                    "setup:default_group",
                    "setup:create_widgets",
                    "setup:create_pages"] do
end

desc "Upgrade"
task :upgrade => [:environment] do
end

namespace :self do
  USERS = ['Alex Bredariol Grilo',
           'André Lima',
           'Arthur Azevedo de Amorim',
           'Helder Ribeiro',
           'Murilo Pereira',
           'Ricardo Panaggio',
           'Vanessa Myho']
  task :create_users => :environment do
    USERS.each do |name|
      User.create!(:name => name,
                   :email => "#{name.split.first.downcase}@umamao.com",
                   :login => "#{name.split.first.downcase}@umamao.com",
                   :password => 'tijolo22',
                   :password_confirmation => 'tijolo22',
                   :role => Time.now,
                   :confirmed_at => Time.now,
                   :agrees_with_terms_of_service => true)
    end
  end
end

namespace :bootstrap do
  task :self => [:environment, 'bootstrap', 'self:create_users']
end

namespace :setup do
  desc "Reset databases"
  task :reset => [:environment] do
    MongoMapper.connection.drop_database(MongoMapper.database.name)
  end

  desc "Reset admin password"
  task :reset_password => :environment do
    admin = User.find_by_login("admin")
    admin.encrypted_password = nil
    admin.password = "admins"
    admin.password_confirmation = "admins"
    admin.save
  end

  desc "Create the default group"
  task :default_group => [:environment] do
    default_tags = %w[technology business science politics religion
                               sports entertainment gaming lifestyle offbeat]

    subdomain = AppConfig.application_name.gsub(/[^A-Za-z0-9\s\-]/, "")[0,20].strip.gsub(/\s+/, "-").downcase
    default_group = Group.new(:name => AppConfig.application_name,
                              :subdomain => subdomain,
                              :domain => AppConfig.domain,
                              :description => "question-and-answer website",
                              :legend => "question and answer website",
                              :default_tags => default_tags,
                              :state => "active")

    default_group.save!
    if admin = User.find_by_login("admin")
      default_group.owner = admin
      default_group.add_member(admin, "owner")
    end
    default_group.save
  end

  desc "Create default widgets"
  task :create_widgets => :environment do
    default_group = Group.find_by_domain(AppConfig.domain)

    if AppConfig.enable_groups
      default_group.widgets << GroupsWidget.new
    end
    default_group.widgets << UsersWidget.new
    default_group.save!
  end

  desc "Create admin user"
  task :create_admin => [:environment] do
    admin = User.new(:login => "admin", :password => "admins",
                                        :password_confirmation => "admins",
                                        :email => "shapado@example.com",
                                        :role => "admin",
					:confirmed_at => Time.now)

    admin.save(:validate => false)
  end

  desc "Create user"
  task :create_user => [:environment] do
    user = User.new(:login => "user", :password => "user123",
                                      :password_confirmation => "user123",
                                      :email => "user@example.com",
                                      :role => "user")
    user.save!
  end

  desc "Create pages"
  task :create_pages => [:environment] do
    Dir.glob(Rails.root+"db/fixtures/pages/*.markdown") do |page_path|
      basename = File.basename(page_path, ".markdown")
      title = basename.gsub(/\.(.*)/, "").titleize
      language = $1

      body = File.read(page_path)

      puts "Loading: #{title.inspect} [lang=#{language}]"
      Group.find_each do |group|
        if Page.count(:title => title, :language => language, :group_id => group.id) == 0
          Page.create(:title => title, :language => language, :body => body, :user_id => group.owner, :group_id => group.id)
        end
      end
    end
  end

  desc "Reindex data"
  task :reindex => [:environment] do
    class Question
      def update_timestamps
      end
    end

    class Answer
      def update_timestamps
      end
    end

    class Group
      def update_timestamps
      end
    end

    $stderr.puts "Reindexing #{Question.count} questions..."
    Question.find_each do |question|
      question._keywords = []
      question.rolling_back = true
      question.save(:validate => false)
    end

    $stderr.puts "Reindexing #{Answer.count} answers..."
    Answer.find_each do |answer|
      answer._keywords = []
      answer.rolling_back = true
      answer.save(:validate => false)
    end

    $stderr.puts "Reindexing #{Group.count} groups..."
    Group.find_each do |group|
      group._keywords = []
      group.save(:validate => false)
    end
  end
end

