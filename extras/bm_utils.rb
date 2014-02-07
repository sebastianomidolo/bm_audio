
def bm_regexp_collocazione
  /((((\d+|AMA|AUD|CLA)\.(F|P|FF|MC|A))|((CD\.\d+)))(\.[^ ]*)) ?/
end

def bm_collocazione?(fname)
  x = bm_regexp_collocazione =~ fname
  x.nil? ? false : true
end

def bm_get_collocazione(fname)
  bm_regexp_collocazione =~ fname
  return nil if $1.blank?
  $1
end
