# Files uploaded to the site by the users.

class UploadedFile
  include MongoMapper::Document

  timestamps!

  key :original_filename, String, :required => true

  belongs_to :user, :required => true

  belongs_to :group

  attr_reader :file

  validate :check_file_presence, :if => lambda { |uf| uf.new? }
  validate :check_file_size, :if => lambda { |uf| uf.file.present? }

  after_create :store_file!

  before_destroy :remove_file_from_storage!

  # Maximum allowed filesize
  def self.maxsize
    20 * 1024 * 1024 # 20MB
  end

  # Carrierwave uploader used to communicate with storage
  def self.uploader
    FileUploader
  end

  def initialize(options = {})
    @file = options.delete :file
    if @file.present?
      self.original_filename =
        if @file.respond_to? :original_filename
          File.basename @file.original_filename
        else
          File.basename @file.path
        end
    end
    super
  end

  # Return the file's extension
  def extension
    self.original_filename.match(/\.(\w+)$/)[1].downcase
  end

  # Return the filename as in the storage container.
  def filename
    self.original_filename
  end

  # The url to the file in storage
  def url
    self.mount.url
  end

  def can_be_destroyed_by?(user)
    self.user == user || self.group.present? && user.owner_of?(self.group)
  end

  # Remove the corresponding file from storage
  def remove_file_from_storage!
    self.mount.remove!
  end

  def store_file!
    # TODO: destroy self if upload doesn't work
    uploader = self.class.uploader.new(self)
    uploader.store!(@file)
  end

  # Return an uploader to interact with the file remotely
  def mount
    uploader = self.class.uploader.new(self)
    # This actually doesn't retrieve the file on the server, but sets
    # the uploader's state so we can get the url.
    uploader.retrieve_from_store!(self.filename)
    uploader
  end

  # Check that a file was given upon creation
  def check_file_presence
    if @file.blank?
      self.errors.add(:file, I18n.t("uploaded_files.errors.blank"))
      return false
    end
    true
  end

  # Check that the given file is not too large
  def check_file_size
    size =
      # File instances in 1.8.7 do not respond to :size
      if @file.respond_to? :size
        @file.size
      else
        File.size(@file.path)
      end
    if size > self.class.maxsize
      self.errors.add(:file, I18n.t("uploaded_files.errors.size"))
      return false
    end
    true
  end

end
