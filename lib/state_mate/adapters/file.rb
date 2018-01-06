# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------

# Deps
# -----------------------------------------------------------------------

# Project / Package
# -----------------------------------------------------------------------


# Refinements
# =======================================================================


# Declarations
# =======================================================================


# Definitions
# =======================================================================


# Abstract base class for adapters whose data is stored in a single file.
# 
class StateMate::Adapters::File
  
  # Constants
  # ======================================================================
  
  
  # Class Methods
  # ======================================================================
  
  # *pure*
  # 
  # Parses a key into path segments, the first of which should be the file
  # path.
  # 
  # Checks that there is at least one resulting segment and that none of the
  # segments are empty.
  # 
  # If `key` is an array, assumes it's already split, and just checks that 
  # the segments meet the above criteria, allowing key segments that contain
  # the key separator (which defaults to the
  # {StateMate::Adapters::DEFAULT_KEY_SEP} `:`).
  # 
  # @example `:`-separated string key
  #   parse_key '/Users/nrser/what/ever.json:x:y:z'
  #   # => ['/Users/nrser/what/ever.json', 'x', 'y', 'z']
  # 
  # @example Array key with segments containing `:`
  #   parse_key ['/Users/nrser/filename:with:colons.json', 'x', 'y']
  #   # => ['/Users/nrser/filename:with:colons.json', 'x', 'y']
  #
  # @param key [Array<String>, String] an Array of non-empty Strings or a
  #     a String that splits by `:` into an non-empty Array of non-empty
  #     Strings.
  # 
  # @return [Array<String, Array<String>>] the String domain followed by an
  #     array of key segments.
  # 
  # @raise [ArgumentError] if the key does not parse into a non-empty list
  #     of non-empty strings.
  #
  def self.parse_key key, key_sep = StateMate::Adapters::DEFAULT_KEY_SEP
    strings = case key
    when Array
      key
    when String
      key.split key_sep
    else
      raise TypeError,
        "key must be string or array, not #{ key.inspect }"
    end # case
    
    # make sure there is at least one element
    if strings.empty?
      raise ArgumentError,
        "key parsed into empty list: #{ key.inspect }"
    end
    
    # check for non-strings, empty domain or key segments
    strings.each do |string|
      if !string.is_a?(String) || string.empty?
        raise ArgumentError.new NRSER.squish <<-END
          all key segments must be non-empty,
          found #{ string.inspect } in key #{ key.inspect }.
        END
      end
    end

    strings
  end # ::parse_key
  
  
  # Attributes
  # ======================================================================
  
  
  # Constructor
  # ======================================================================
  
  # Instantiate a new `StateMate::Adapters::File`.
  def initialize
    
  end # #initialize
  
  
  # Instance Methods
  # ======================================================================
  
  
  # Parse file contents into state structure.
  # 
  # @abstract
  # 
  # @param [String] file_contents
  #   File contents to parse.
  # 
  # @return [Hash]
  #   @todo Document return value.
  # 
  def parse file_contents
    raise NRSER::AbstractMethodError.new self, __method__ 
  end # #parse
  
  
  
  # @todo Document read method.
  # 
  # @param [type] arg_name
  #   @todo Add name param description.
  # 
  # @return [return_type]
  #   @todo Document return value.
  # 
  def read key, **options
    
  end # #read
  
  
end # class StateMate::Adapters::File
