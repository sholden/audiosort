require "audiosort/version"

require 'id3tag'
require 'logger'
require 'fileutils'

module Audiosort
  class Error < StandardError; end

  class Sorter
    attr_reader :from_path, :to_path, :logger

    def initialize(from_path:, to_path:)
      @from_path, @to_path = from_path, to_path
      @logger = Logger.new(STDOUT)
    end

    def call
      mp3path = File.join(from_path, '**', '*.mp3')
      mp3_files = Dir[mp3path]

      mp3_dirs = mp3_files.each_with_object(Hash.new{|h, k| h[k] = []}).each do |path, dirs|
        dirs[File.dirname(path)] << path
      end

      mp3_dirs.each do |dir, files|
        artists = []
        albums = []

        files.each do |path|
          File.open(path, 'rb') do |f|
            tag = ID3Tag.read(f)
            artists << tag.artist.gsub(/\s*#{Regexp.escape(File::SEPARATOR)}\s*/, ' - ')
            albums << tag.album.gsub(/\s*#{Regexp.escape(File::SEPARATOR)}\s*/, ' - ')
          end
        end

        artists = artists.reject(&:empty?).uniq
        albums = albums.reject(&:empty?).uniq
        if artists.count != 1
          logger.error("Bad Artists: #{artists.inspect}") if artists.count != 1
          next
        elsif albums.count != 1
          logger.error("Bad Albums: #{albums.inspect}")
          next
        end

        to_copy = Dir[File.join(dir, '*')].reject{|path| File.directory?(path)}
        author_title_dir = File.join(to_path, artists.first, albums.first)
        logger.info "Copying #{to_copy.count} files from #{dir} to #{author_title_dir}"
        FileUtils.mkdir_p(author_title_dir)
        to_copy.each{|f| FileUtils.cp(f, File.join(author_title_dir, File.basename(f)))}
      end
    end
  end
end
