# -*- mode: ruby;-*-

desc 'Creazione clips mp3'

task :make_audioclips => :environment do
  include DigitalObjects
  numfiles=0
  # 'bm-1/VENEGONI_CD/002_SCANS_fare',
  dirs=[
        'bm-1/VENEGONI_CD',
        'bm-4',
        'bm-5',
        'ITER',
        'bm-1/TRIBERTI_CD',
        'bm-1/CD Biblioteca Musicale',
        'bm-1/VINILI DIGITALIZZATI/www/db_aux',
        'bm-3',
       ]

  dirs.each do |folder|
    # puts "folder: #{folder}"
    numfiles += make_audioclips(File.join(digital_objects_mount_point, '', folder))
    # puts "visti finora #{numfiles} files"
  end
  puts "make_audioclips => totale files analizzati #{numfiles}"
end


