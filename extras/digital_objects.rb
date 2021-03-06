require 'filemagic'
require 'rexml/document'
require 'mp3info'
load 'bm_utils.rb'

FILENAME_METADATA_TAGS=[:au,:ti,:an,:mid,:pp,:uid,:sc,:dc]

module DigitalObjects
  def digital_objects_mount_point
    config = Rails.configuration.database_configuration
    config[Rails.env]["digital_objects_mount_point"]
  end

  def digital_objects_cache
    config = Rails.configuration.database_configuration
    config[Rails.env]["digital_objects_cache"]
  end


  # http://bctdoc.selfip.net/documents/30
  def get_bibdata_from_filename
    res={}
    self.filename.split('/').each do |part|
      part.split('#').each do |e|
        tag,data=e.split('_')
        # puts "tag #{tag} contiene '#{data}'"
        ts=tag.to_sym
        res[ts]=data if FILENAME_METADATA_TAGS.include?(ts) and !data.blank?
      end
    end
    res
  end

  def digital_objects_dirscan(dirname, fdout, folder='', prec_folder='')
    puts "analizzo dir #{dirname}"
    fm=FileMagic.mime

    mp=digital_objects_mount_point
    filecount=0
    Dir[(File.join(dirname,'*'))].each do |entry|
      dirname=File.dirname(entry)
      if prec_folder!=dirname
        folder=dirname.sub(prec_folder,'').sub(/^\//,'')
        # puts "cambio da #{prec_folder}\n   =====> #{dirname}\n  folder=>#{folder}"
        prec_folder=dirname
      end

      if File.directory?(entry)
        filecount += digital_objects_dirscan(entry, fdout, folder, prec_folder)
      else
        # utf8_entry=entry.encode('utf-8','iso-8859-15')
        begin
          fstat = File.stat(entry)
          mtype = fm.file(entry)
        rescue
          puts "errore: #{$!}"
          next
        end
        if (colloc=bm_get_collocazione(entry)).nil?
          # puts "no collocazione => #{entry}"
          # next
        end

        # mime-type: audio/mpeg
        # mime-type: audio/x-ape
        # mime-type: audio/x-flac
        # mime-type: audio/x-wav

        # tags="\\N"
        tags=nil

        b_entry=entry.sub(mp,'')
        
        case mtype.split(';').first
        when 'audio/x-ape'
          # puts entry
          begin
            af=ApeFile.new(entry)
          rescue
            puts "File ape: #{entry}"
            puts "errore: #{$!}"
            next
          end
          # puts "qui: #{af.inspect}"
          tags=af.tracklist_xml(colloc,folder)
        when 'audio/x-flac'
          begin
            ff=FlacFile.new(entry)
          rescue
            puts "File flac: #{entry}"
            puts "errore: #{$!}"
            next
          end
          # puts entry
          # puts "precfolder #{prec_folder}"
          # puts "   dirname #{dirname}"
          begin
            tags=ff.tracklist_xml(colloc,folder)
          rescue
            puts "Errore da tracklist_xml: #{$!}"
            puts "File che ha provocato l'errore: #{entry}"
          end
        when 'audio/mpeg'
          mp3=Mp3Info.open(entry)
          if !mp3.tag.title.nil?
            doc = REXML::Document.new("<tracklist></tracklist>")
            doc.root.attributes['colloc']=colloc
            doc.root.attributes['folder']=folder
            e=REXML::Element.new('title')
            e.text=mp3.tag.title
            e.attributes['position']=mp3.tag.tracknum
            doc.root.add_element(e)
            tags=doc.root.to_s
          end
          mp3.close
        else
          # puts "non trattato: #{mtype}"
          next
        end
        next if tags.nil?

        if entry =~ /\.mp3$/i and mtype != 'audio/mpeg; charset=binary'
          puts "wrong mime type '#{mtype}'?: #{entry}"
        end

        filecount += 1
        fdout.write("bm::#{b_entry}\t#{fstat.size}\t#{fstat.ctime}\t#{fstat.mtime}\t#{fstat.atime}\t#{mtype}\t#{tags}\n")
      end
    end
    # puts "totale files: #{filecount}"
    filecount
  end

  def make_audioclips(dirname)
    # puts "make_audioclips in #{dirname}"
    fm=FileMagic.mime
    mp=digital_objects_mount_point
    filecount=0
    Dir[(File.join(dirname,'*'))].each do |entry|
      if File.directory?(entry)
        filecount += make_audioclips(entry)
      else
        begin
          fstat = File.stat(entry)
          mtype = fm.file(entry)
        rescue
          puts "errore: #{$!}"
          next
        end
        if (colloc=bm_get_collocazione(entry)).nil?
          # puts "no collocazione => #{entry}"
          # next
        end
        case mtype.split(';').first
        when 'audio/mpeg'
          puts File.basename(entry)
          DObject.new({mime_type: mtype, filename: entry.sub(mp,'')}).digital_object_create_audioclip
          filecount += 1
        when 'audio/x-flac'
          puts "flac: #{entry}"
          ff=FlacFile.new(entry)
          ff.make_mp3_audioclips
          next
        end

      end
    end
    filecount
  end

  def digital_object_read_metadata
    fname = File.join(digital_objects_mount_point,filename)
    fstat = File.stat(fname)
    puts fstat.inspect
    puts "id: #{id}"
    puts self.attributes
    self.bfilesize = File.size(fname)
  end

  def audioclip_basename
    self.filename
  end
  def audioclip_basedir
    config = Rails.configuration.database_configuration
    config[Rails.env]['digital_objects_audioclips']
  end
  def audioclip_filename
    File.join(audioclip_basedir,audioclip_basename)
  end

  def digital_object_create_audioclip(seconds=30)
    return nil if self.mime_type!='audio/mpeg; charset=binary'
    fn=self.filename_with_path
    if !(fn =~ /\`/).nil?
      puts "Errore nome file: #{fn}"
      return nil
    end
    target=audioclip_filename
    return target if File.exists?(target) and File.size(target)>0
    FileUtils.mkpath(File.dirname(target))
    cmd=%Q{/usr/bin/sox "#{fn}" "#{target}" trim 0 #{seconds} fade h 0 0:0:#{seconds} 4}
    Kernel.system(cmd)
    mp3=Mp3Info.open(target)
    mp3.tag2.TCOP="Biblioteche civiche torinesi - Sistema audio Biblioteca Andrea Della Corte"
    mp3.tag2.WOAS="http://bct.comperio.it/"
    mp3.tag2.COMM="Preascolto traccia audio"
    mp3.close
    target
  end

end
