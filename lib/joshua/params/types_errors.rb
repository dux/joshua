class Joshua
  module Params
    class Parse
      ERRORS = {
        en:{
          bad_format:    'Bad value format',
          not_integer:   'Not an integer',
          min_value:     'Minimal allowed value is: %s',
          max_value:     'Maximal allowed value is: %s',
          email_min:     'Email requireds min of 8 characters',
          email_missing: 'Email is missing @',
          url_start:     'URL is not starting with http or https',
          point_format:  'Point should be in format 1.2345678,1.2345678',
          min_date:      'Minimal allow date is %s',
          max_date:      'Maximal allow date is %s',
          not_in_range:  'Value is not in list of allowed values'
        },

        hr: {
          bad_format:    'Format vrijednosti ne zadovoljava',
          not_integer:   'Nije cijeli broj',
          min_value:     'Minimalna dozvoljena vrijednost je: %s',
          max_value:     'Maksimalna dozvoljena vrijednost je: %s',
          email_min:     'Email zatjeva minimalno 8 znakova',
          email_missing: 'U email-u nedostaje @',
          url_start:     'URL ne započinje sa http ili https',
          point_format:  'Geo točka bi trebala biti u formatu 1.2345678,1.2345678',
          min_date:      'Minimalni dozvoljeni datum je %s',
          max_date:      'Maksimalni dozvoljeni datum je %s',
          not_in_range:  'Podatak nije u listi dozovljenih podataka'
        }
      }
    end
  end
end
