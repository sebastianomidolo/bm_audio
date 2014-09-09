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
        'bm-1/CD Biblioteca Musicale',
        'bm-1/TRIBERTI_CD/000_FINITI',
        'bm-1/VENEGONI_CD/000_FINITI_CATALOGATI',
        'bm-1/VENEGONI_CD/001_FLAC+SCANS',
        'bm-1/VENEGONI_CD/002_SCANS_fare',
        'NObm-1/VINILI DIGITALIZZATI/www/db_aux',
        'bm-3',
       ]
  xdirs=[
        'bm-1/TRIBERTI_CD/000_FINITI/12.F.1446 - Pitura Freska - Duri i banchi'
       ]

  fdout.write(%Q{BEGIN;DROP TABLE public.collocazioni_musicale;COMMIT;
BEGIN;
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
  fdout.write(%Q{CREATE TABLE public.collocazioni_musicale AS
  SELECT id AS d_object_id,
     unnest(xpath('//@colloc',tags))::text AS collocation,
     unnest(xpath('//@folder',tags))::text AS folder,
     unnest(xpath('//@position',tags))::text::integer AS "position",mime_type
   FROM d_objects WHERE tags IS document;
CREATE INDEX collocazioni_musicale_idx ON public.collocazioni_musicale(collocation);
DELETE FROM public.attachments WHERE attachment_category_id = 'E';
INSERT INTO public.attachments
  (d_object_id,attachable_id,attachable_type,attachment_category_id,"position",folder)
  (SELECT DISTINCT cbm.d_object_id,ci.manifestation_id, 'ClavisManifestation','E',cbm.position,cbm.folder
    FROM collocazioni_musicale cbm JOIN clavis.item ci USING(collocation)
     WHERE ci.owner_library_id=3 AND ci.manifestation_id!=0
       AND cbm.mime_type='audio/mpeg; charset=binary');
INSERT INTO public.attachments
  (d_object_id,attachable_id,attachable_type,attachment_category_id,"position",folder)
  (
  SELECT DISTINCT cbm.d_object_id,ci.manifestation_id, 'ClavisManifestation','E',cbm.position,cbm.folder
    FROM collocazioni_musicale cbm JOIN clavis.item ci USING(collocation)
     WHERE ci.owner_library_id=3 AND ci.manifestation_id!=0
      AND cbm.mime_type='audio/x-flac; charset=binary'
      AND cbm.position in (0,1));
ALTER TABLE public.attachments ADD CONSTRAINT "d_object_id_fkey" FOREIGN KEY(d_object_id)
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


