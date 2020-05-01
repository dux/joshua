module ApiModuleClasic
  def self.included base
    base.collection do
      def module_clasic
        'is_module'
      end
    end
  end
end

Joshua.plugin :test_1 do
  collection do
    def plugin_test
      'from_plugin'
    end
  end
end