# -*- mode: ruby;-*-

# Esempio. In development:
# RAILS_ENV=development rake dir_scan
# In production:
# RAILS_ENV=production  rake dir_scan

desc 'Scansione cartelle con files audio e video'

task :dir_scan => :environment do
  include DigitalObjects
  outfile="/home/shared/dir_scan_output.sql"
  # outfile="/tmp/dir_scan_output.sql"
  fdout=File.open(outfile,'w')
  fdout.write(%Q{-- dir_scan started at #{Time.now}\n})
  numfiles=0
  dirs=[
        'xCLA.F. - Classic Voice Allegati',
        'xbm-3/04.F.237 - Maurizio Pollini Edition - 12 CD - DG',
        'bm-1',
        'bm-2',
        'bm-3',
       ]

  fdout.write(%Q{BEGIN;
ALTER TABLE public.attachments DROP CONSTRAINT "d_object_id_fkey";
DELETE FROM public.d_objects WHERE filename LIKE 'bm::%';
SELECT setval('public.d_objects_id_seq', (select max(id) FROM public.d_objects)+1);
COPY public.d_objects (filename, bfilesize, f_ctime, f_mtime, f_atime, mime_type, tags) FROM stdin;\n})
  dirs.each do |folder|
    puts "folder: #{folder}"
    # numfiles+=DObject.fs_scan(folder, fdout)
    numfiles+=digital_objects_dirscan(File.join(digital_objects_mount_point, '', folder), fdout)
  end
  fdout.write("\\.\n")
  fdout.write(%Q{ALTER TABLE public.attachments ADD CONSTRAINT "d_object_id_fkey" FOREIGN KEY(d_object_id)
   REFERENCES public.d_objects ON UPDATE CASCADE ON DELETE CASCADE;\nCOMMIT;\n})
  fdout.write(%Q{-- dir_scan ended at #{Time.now}\n})
  fdout.close

  #config = Rails.configuration.database_configuration
  #dbname=config[Rails.env]["database"]
  #username=config[Rails.env]["username"]
  #cmd="/usr/bin/psql --no-psqlrc --quiet -d #{dbname} #{username}  -f #{tempfile}"
  # puts cmd
  # Kernel.system(cmd)

  puts "dir_scan => totale files analizzati #{numfiles}"
end


