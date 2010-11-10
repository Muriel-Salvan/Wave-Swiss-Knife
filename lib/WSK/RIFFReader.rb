#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  # Class reading RIFF files
  class RIFFReader

    # Constructor
    #
    # Parameters:
    # * *iFile* (_IO_): File to read
    def initialize(iFile)
      @File = iFile
    end

    # Position the file on the data associated to a given RIFF name
    #
    # Parameters:
    # * *iRIFFName* (_String_): The RIFF name
    # Return:
    # * _Exception_: An error, or nil in case of success
    # * _Integer_: The RIFF chunk size
    def setFilePos(iRIFFName)
      rError = nil
      rSize = nil

      # Loop through the names until we find ours
      @File.seek(12)
      lRIFFName, rSize = @File.read(8).unpack('a4V')
      lCurrentPos = 20
      while (lRIFFName != nil)
        if (lRIFFName == iRIFFName)
          # We are positioned correctly
          lRIFFName = nil
          logDebug "Found RIFF chunk #{iRIFFName} of size #{rSize}"
        else
          logDebug "Skip RIFF chunk #{lRIFFName} of size #{rSize}"
          # Go to the next chunk
          @File.seek(lCurrentPos + rSize)
          lData = @File.read(8)
          lCurrentPos += rSize + 8
          if (lData == nil)
            # End of the file
            rError = RuntimeError.new("End of file met: no RIFF #{iRIFFName} chunk found.")
            lRIFFName = nil
          else
            lRIFFName, rSize = lData.unpack('a4V')
          end
        end
      end

      return rError, rSize
    end

  end

end
