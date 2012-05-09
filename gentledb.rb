#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Copyright 2012  Felix Rabe <public@felixrabe.net>

require 'digest/sha2'
require 'fileutils'
require 'stringio'

class Object
  def valid_gentledb_identifier? options={}
    return false unless self.is_a? String
    return false if self.length > GentleDB::IDENTIFIER_LENGTH
    return false if GentleDB::IDENTIFIER_DIGITS !~ self
    return true  if self.length == GentleDB::IDENTIFIER_LENGTH
    return true  if options[:partial]
    return false
  end
end

module GentleDB
  IDENTIFIER_LENGTH = 256 / 4
  IDENTIFIER_DIGITS = /\A[0-9a-f]*\z/

  class GentleDBException < StandardError; end
  class InvalidIdentifierException < GentleDBException; end

  def self.validate_identifier identifier, options={}
    if not identifier.valid_gentledb_identifier? options
      raise InvalidIdentifierException, identifier
    end
  end

  def self.~@
    32.times.map { |i| "%02x" % rand(256) } .join
  end

  def self.create_file_with_mode filename, mode
    file = File.new filename, "wb"
    file.chmod mode
    if block_given?
      result = yield file
      file.close
      return result
    else
      return file
    end
  end

  class Memory
    def initialize
      @content_db = {}
      @pointer_db = {}
    end

    def to_s
      "#<GentleDB: (in memory)>"
    end

    def ~@
      ~GentleDB
    end

    def + content
      content_identifier = Digest::SHA256.hexdigest content
      @content_db[content_identifier] = content
      return content_identifier
    end

    alias :<< :+

    def - content_identifier
      GentleDB::validate_identifier content_identifier
      return @content_db[content_identifier]
    end

    alias :>> :-

    def []= pointer_identifier, content_identifier
      GentleDB::validate_identifier pointer_identifier
      if content_identifier
        GentleDB::validate_identifier content_identifier
        @pointer_db[pointer_identifier] = content_identifier
      else
        @pointer_db.delete pointer_identifier
      end
      return pointer_identifier
    end

    def [] pointer_identifier
      GentleDB::validate_identifier pointer_identifier
      return @pointer_db[pointer_identifier]
    end

    def file content_identifier=nil
      if content_identifier
        file = InFile.new self, content_identifier
      else
        file = OutFile.new self
      end

      if block_given?
        result = yield file
        file.close
        return result
      else
        return file
      end
    end

    class InFile
      def initialize db, content_identifier
        @db = db
        @content_identifier = content_identifier
        @content_file = StringIO.new @db - content_identifier
      end

      def method_missing method, *args, &block
        @content_file.send method, *args, &block
      end
    end

    class OutFile
      def initialize db
        @db = db
        @hash = Digest::SHA256.new
        @data = StringIO.new
      end

      def write string
        @hash << string
        @data << string
        string.length
      end

      def close ; end

      def ~@
        content_identifier = @hash.hexdigest
        content_db = @db.instance_variable_get :@content_db
        content_db[content_identifier] = @data.string
        content_identifier
      end
    end
  end

  FS_DEFAULT_DIRECTORY = "~/.gentledb"

  class FS
    def initialize directory=nil
      directory ||= "~/.gentledb"
      @directory = File.expand_path directory
      @content_directory = File.join @directory, "content_db"
      @pointer_directory = File.join @directory, "pointer_db"
      @tmp_directory = File.join @directory, "tmp"

      [@directory, @content_directory, @pointer_directory, @tmp_directory].each \
      do |directory|
        unless File.exists? directory
          begin
            Dir.mkdir directory, 0700
          rescue
            raise GentleDBException,
                  "Could not create directory #{directory.inspect}"
          end
        end
      end
    end

    def to_s
      "#<GentleDB: #@directory>"
    end

    def ~@
      ~GentleDB
    end

    def self._id_to_path directory, id, options={}
      idpath = [0..1, 2..3, 4..6, 7..-1].map{ |r| id[r] }
      idpath.select!{ |s| s and not s.empty? }
      directory = File.join directory, *idpath[0...-1]
      unless options[:create_dir] == false  # default (nil) means true
        FileUtils.mkdir_p directory, mode: 0700 unless File.exists? directory
      end
      File.join directory, idpath[-1]
    end

    def _content_filename *args
      FS::_id_to_path @content_directory, *args
    end

    def _pointer_filename *args
      FS::_id_to_path @pointer_directory, *args
    end

    def _find_partial_id directory, partial_id
      id = partial_id + "?" * (64 - partial_id.length)
      path_to_glob = FS::_id_to_path directory, id, create_dir: false
      Dir.glob(path_to_glob).map do |f|
        f[directory.length..-1].gsub File::SEPARATOR, ""
      end
    end

    def + content
      file do |f|
        f.write content
        ~f
      end
    end

    alias :<< :+

    def - content_identifier
      GentleDB::validate_identifier content_identifier
      file content_identifier do |f|
        f.read
      end
    end

    alias :>> :-

    def []= pointer_identifier, content_identifier
      GentleDB::validate_identifier pointer_identifier
      if content_identifier
        GentleDB::validate_identifier content_identifier
        filename = _pointer_filename pointer_identifier, create_dir: true
        GentleDB::create_file_with_mode filename, 0600 do |f|
          f.write content_identifier
        end
      else
        filename = _pointer_filename pointer_identifier, create_dir: false
        if File.exists? filename
          File.delete filename
        end
      end
      return pointer_identifier
    end

    def [] pointer_identifier
      GentleDB::validate_identifier pointer_identifier
      filename = _pointer_filename pointer_identifier, create_dir: false
      File.open(filename, "rb").read
    end

    def file content_identifier=nil
      if content_identifier
        file = InFile.new self, content_identifier
      else
        file = OutFile.new self
      end

      if block_given?
        result = yield file
        file.close
        result = ~file unless content_identifier
        return result
      else
        return file
      end
    end

    class InFile
      def initialize db, content_identifier
        filename = db._content_filename content_identifier, create_dir: false
        @content_file = File.open filename, "rb"
      end

      def method_missing method, *args, &block
        @content_file.send method, *args, &block
      end
    end

    class OutFile
      def initialize db
        @db = db
        @hash = Digest::SHA256.new
        directory = @db.instance_variable_get :@tmp_directory
        @tmpfile_path = File.join directory, ~GentleDB
        @tmpfile = GentleDB::create_file_with_mode @tmpfile_path, 0600
        @is_open = true
      end

      def write string
        @hash << string
        @tmpfile << string
      end

      alias :<< :write

      def close
        return unless @is_open
        @tmpfile.chmod 0400
        @tmpfile.close
        @is_open = false
        content_identifier = ~self
        filename = @db._content_filename content_identifier, create_dir: true
        if File.exists? filename  # do not overwrite existing content
          File.delete @tmpfile_path
        else
          File.rename @tmpfile_path, filename
        end
      end

      def ~@
        close if @is_open
        @hash.hexdigest
      end
    end
  end
end


if __FILE__ == $0
  [GentleDB::FS, GentleDB::Memory].each do |cls|
    g = cls.new
    print g, " ", ~g, " ", ~GentleDB, "\n"
    puts g + "Ruby says 'Hello'!"
    puts g << "Ruby says 'Hello' again!"
    puts g - "57ffde55dfc1e5f6ea6630edb8e015ebd94858791b6b2ec16d6c0aeef4c17dd0"
    puts g - "e983aa8534cb5f650ede8f6f6f3218750c1fb4baa04bb83414a1dda2192b2df2"
  end
end
