# lastmod 30 gennaio 2014
# lastmod  5 ottobre 2012   - bug fix in sox_split_info
# lastmod  4 settembre 2012 - def sox_split_info
# lastmod 30 agosto 2012
# lastmod 29 agosto 2012

class FlacFile

  attr_reader :flac_filename, :cue_filename

  def initialize(flac_filename,cue_filename=nil)
    return nil if File.extname(flac_filename.downcase)!='.flac'
    @flac_filename=flac_filename
    if !cue_filename.nil?
      @cue_filename=cue_filename
    else
      fname=@flac_filename.sub(/.flac$/,'.cue')
      if !File.exists?(fname)
        cuefiles=Dir.glob(File.join(File.dirname(@flac_filename),'*.cue'), File::FNM_CASEFOLD)
        if cuefiles.size==1
          @cue_filename=cuefiles.first
        else
          # puts "file cue non trovato per #{File.basename(@flac_filename)}"
          @cue_filename=nil
        end
      else
        @cue_filename=fname
      end
    end
    self
  end

  def valid_cue_file?
    return nil if self.cue_filedata.nil?
    begin
      ext=File.extname(cue_head_block('FILE').downcase)
    rescue
      fd=File.open("/tmp/errori_formato_cue.txt", 'a+')
      fd.write(%Q{#{self.cue_filename}\n})
      fd.close
      return false
    end
    ext=='.flac' ? true : false
  end

  def cue_filedata
    return nil if @cue_filename.nil?
    return @cue_filedata if !@cue_filedata.nil?
    data=File.read(@cue_filename)
    filemagic=FileMagic.mime.file(@cue_filename)
    if !(filemagic =~ /charset=(.*) ?/).nil?
      # puts "charset: #{$1}"
      begin
        data.encode!('utf-8',$1) if $1!='utf-8'
      rescue
        puts "cue_filedata => #{$!} (file #{@cue_filename}"
        return nil
      end
    end
    @cue_filedata=data.gsub("\r",'').gsub('  INDEX 0','  INDEX0').gsub("\t",' ')
  end

  def make_mp3_audioclips(seconds=30)
    sox_info=self.sox_split_info
    return nil if sox_info.nil?

    config = Rails.configuration.database_configuration
    dirname=File.dirname(@flac_filename).sub(digital_objects_mount_point,'')
    outdir=File.join(config[Rails.env]['digital_objects_audioclips'],dirname)
    FileUtils.mkpath(outdir)
    tracks=self.cue_tracklist
    cnt=0
    sox_info.each do |si|
      puts si.inspect
      tags=tracks[cnt]
      cnt+=1
      tracknum,start,len=si
      begin
        target=File.join(outdir, format("%03d%s", tracknum, '.mp3'))
        puts target
        next if File.exists?(target) and File.size(target)>0
        cmd=%Q{/usr/bin/sox "#{@flac_filename}" "#{target}" trim #{start} #{seconds} fade h 0 0:0:#{seconds} 4}
        puts cmd
        Kernel.system(cmd)
        mp3=Mp3Info.open(target)
        mp3.tag
        mp3.tag.title=tags['title']
        mp3.tag.artist=tags['artist']
        mp3.tag.tracknum=cnt
        mp3.tag2.TCOP="Biblioteche civiche torinesi - Sistema audio Biblioteca Andrea Della Corte"
        mp3.tag2.WOAS="http://bct.comperio.it/"
        mp3.tag2.COMM="Preascolto traccia audio"
        mp3.close
      rescue
        puts "Errore FlacFile#make_mp3_audioclips: #{$!}"
      end
    end
  end

  def cue_head_block(tag=nil)
    return nil if self.cue_filedata.nil?
    data=self.cue_filedata.split("\n  TRACK")
    # data=self.cue_filedata.split("\nTRACK") if data.size < 2
    return nil if data.size < 2
    data=data.first
    if tag.blank?
      data
    else
      # puts "estrazione tag #{tag}"
      reg=Regexp.new("^#{tag}")
      res=''
      data.split("\n").each do |l|
        if reg =~ l
          if /"(.*)"/ =~ l
            res=$1
            break
          end
        end
      end
      res
    end
  end

  # NB: trackblock se !nil deve essere un elemento dell'array che si ottiene
  # con cue_tracklist_blocks, tipo questo:
  # 03 AUDIO
  #   TITLE "Couperin"
  #   PERFORMER "Elio Amato, piano; Alberto Amato, double bass; Loris Amato, drums"
  #   INDEX 00 08:31:43
  #   INDEX 01 08:33:42
  def get_track_number(trackblock=nil)
    if trackblock.blank?
      n=self.tags_from_flac['tracknumber'].to_i
    else
      n=trackblock.to_i
    end
    n==0 ? 'nil' : n
  end

  def cue_tracklist
    d=self.cue_tracklist_blocks
    return [] if d.nil?

    album_title=self.cue_head_block('TITLE')
    album_performer=self.cue_head_block('PERFORMER')

    trlist=[]
    d.each do |t|
      tracknumber=self.get_track_number(t)
      # puts "tracknumber: #{tracknumber}"
      lines=t.split("\n")
      lines.shift
      tracks={}
      tracks['tracknumber']=tracknumber
      lines.each do |e|
        if /(TITLE|PERFORMER|INDEX00|INDEX01) (.*)/ =~ e
          label=String.new($1)
          val=$2.gsub('"','')
          eval %Q{tracks[label.downcase]=val}
        end
      end
      # puts "tracks: #{tracks.keys}"
      tracks['album']=album_title
      tracks['album']='[missing title]' if tracks['album'].blank?
      trlist << tracks
    end
    trlist
  end

  def cue_tracklist_blocks
    return nil if self.cue_filedata.nil?
    data=self.cue_filedata.split("\n  TRACK")
    return nil if data.size < 2
    data.shift
    data
  end

  def tags_from_flac
    tf=Tempfile.new('flactmp')
    outfile=tf.path
    cmd=%Q{/usr/bin/metaflac --export-tags-to=#{outfile} "#{self.flac_filename}"}
    # puts cmd
    Kernel.system(cmd)
    data=File.read(tf.path)
    tf.close(true)
    h={}
    data.each_line do |l|
      l.chomp!
      tag,content=l.split('=')
      next if content.blank?
      h[tag.downcase]=content
    end
    h
  end

  def sox_split_info
    return nil if !self.valid_cue_file?
    def timediff(a,b)
      a_min,a_sec=a
      b_min,b_sec=b
      min_diff=b_min.to_i - a_min.to_i
      sec_diff=b_sec.to_i - a_sec.to_i
      if sec_diff<0
        sec_diff+=60
        min_diff-=1
      end
      # puts "timediff #{a_min}:#{a_sec} - #{b_min}:#{b_sec} => #{min_diff}:#{sec_diff}"
      format "%02d:%02d", min_diff,sec_diff
    end
    prectime=''
    cnt=0
    tracktime=nil
    soxtrims=[]
    self.cue_tracklist.each do |t|
      tt=t['index01']
      next if tt.blank?
      tt=tt.split(':')[0..1]
      tracktime=tt
      if !prectime.blank?
        td=timediff(prectime,tt)
        # puts "#{cnt} #{prectime.inspect} -- #{tt.inspect} => #{td}"
        # soxtrims << [(format "%02d",cnt), prectime.join(':'), td]
        soxtrims << [cnt, prectime.join(':'), td]
      end
      prectime=tt
      cnt+=1
    end
    # soxtrims << [(format "%02d",cnt), tracktime.join(':'), nil]
    soxtrims << [cnt, tracktime.join(':'), nil]
    # puts "last tracktime start: #{tracktime.join(':')}"
    #soxtrims.each do |st|
    #  puts "trim: #{st.inspect}"
    #end
    soxtrims
  end

  def sql_copy(fname,folder,fd=STDOUT)
    self.cue_tracklist.each do |t|
      fd.write("#{@flac_filename}\t#{folder}\t#{t['tracknumber']}\t#{t['title']}\n")
    end
  end

  def tracklist_xml(colloc,folder)
    doc = REXML::Document.new("<tracklist></tracklist>")
    doc.root.attributes['colloc']=colloc
    doc.root.attributes['folder']=folder
    if self.valid_cue_file?
      self.cue_tracklist.each do |t|
        e=REXML::Element.new('title')
        title=t['title'].blank? ? '[titolo_mancante]' : t['title']
        e.text=title.gsub('\\', '')
        e.attributes['position']=t['tracknumber']
        e.attributes['index00']=t['index00']
        e.attributes['index01']=t['index01']
        doc.root.add_element(e)
      end
    else
      tags=self.tags_from_flac
      e=REXML::Element.new('title')
      e.text=tags['title']
      e.attributes['position']=tags['tracknumber'].to_i
      doc.root.add_element(e)
    end
    doc.root.to_s
  end

end
