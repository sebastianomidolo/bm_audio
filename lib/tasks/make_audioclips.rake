# -*- mode: ruby;-*-

desc 'Creazione clips mp3'

task :make_audioclips => :environment do
  include DigitalObjects
  numfiles=0
  dirs=[
        'bm-1/TRIBERTI_CD/000_FINITI',
        'bm-1/CD Biblioteca Musicale',
        'bm-1/VENEGONI_CD/000_FINITI_CATALOGATI',
        'bm-1/VENEGONI_CD/001_FLAC+SCANS',
        'bm-1/VENEGONI_CD/002_SCANS_fare',
        'bm-1/VINILI DIGITALIZZATI/www/db_aux',
        'bm-3',
       ]

  dirs.each do |folder|
    puts "folder: #{folder}"
    numfiles += make_audioclips(File.join(digital_objects_mount_point, '', folder))
    # puts "visti finora #{numfiles} files"
  end
  puts "make_audioclips => totale files analizzati #{numfiles}"
end


