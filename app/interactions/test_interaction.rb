      class TestInteraction < ActiveInteraction::Base
        boolean :dt, default: true
        boolean :df, default: false
        
        def execute
          puts "dt" if dt
          puts "df" if df
        end
      end
