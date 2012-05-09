#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Copyright 2012  Felix Rabe <public@felixrabe.net>

require 'java'

module SwingDSL
  def self.constize name
    name.to_s.split('_').map(&:capitalize).join
  end

  def self.instantiate_component const, parent, args, &block
    options = {}
    if args[-1].instance_of? Hash
      options = args.pop
    end
    thing = const.new parent, *args
    thing.process_options options
    thing.process_block &block if block
    thing.post_block
    thing.return_value
  end

  class SuperClass
    attr_accessor :parent
    attr_reader :j

    def initialize parent, *args
      self.parent = parent
      @j = create_j *args
      post_init
    end

    def parent= parent
      @parent = parent
    end

    def create_j *args
      class_name = self.class.name.split("::")[-1]
      jname = "javax.swing.J" + class_name
      name  = "javax.swing."  + class_name
      # Java::JavaxSwing::const_get doesn't work, had to use 'eval' here:
      const = (eval jname rescue nil) || (eval name)
      const.new *args
    end

    def post_init
      @parent.add @j
    end

    def method_missing name, *args, &block
      if (const = self.class.const_get(SwingDSL::constize name) rescue nil) ||
          (const = SwingDSL::const_get(SwingDSL::constize name) rescue nil)
        SwingDSL::instantiate_component const, self, args, &block
      elsif @j.respond_to? name
        @j.send name, *args, &block
      else
        super
      end
    end

    def process_options options
      options.each_pair do |k, v|
        send k.to_s + "=", v
      end
    end

    def process_block &block
      instance_eval &block
    end

    def post_block
    end

    def return_value
      self
    end
  end

  class Button < SuperClass
    def process_block &block
      @j.add_action_listener &block
    end
  end

  class ButtonGroup < SuperClass
    def post_init ; end  # don't add to parent

    def add thing
      @j.add thing
      @parent.add thing
    end
  end

  class Frame < SuperClass
    def parent= parent ; end  # parent is ignored

    def post_init
      @j.default_close_operation = javax.swing.JFrame::DISPOSE_ON_CLOSE
    end

    def process_options options
      super
      if options.has_key? :size
        @dont_pack = true  # why?
      end
    end

    def post_block
      pack unless @dont_pack
      self.visible = true
    end

    attr_reader :menubar
    def menubar= mb
      @menubar = mb
      set_jmenu_bar mb
      @menubar
    end

    class Content < SuperClass
      def create_j
        @parent.content_pane
      end

      def post_init
        @constraint = nil
      end

      def to constraint, &block  # do not nest calls to this method!
        if constraint.instance_of? Symbol
          constraint = java.awt.BorderLayout.const_get constraint.to_s.upcase
        end
        @constraint = constraint
        instance_eval &block
        @constraint = nil
      end

      def add thing
        if @constraint.nil?
          @j.add thing
        else
          @j.add thing, @constraint
        end
      end
    end

    class Glass < SuperClass
      def create_j
        @parent.glass_pane
      end

      def post_init ; end  # don't add to parent
    end

    class Menu < SuperClass
      def parent= parent
        @parent = parent
        @bar = @parent.menubar ||= javax.swing.JMenuBar.new
      end

      def post_init
        @bar.add @j
      end

      def separator
        @j.add_separator
      end

      class Item < SuperClass
        def create_j label
          javax.swing.JMenuItem.new label
        end

        def process_block &block
          @j.add_action_listener &block
        end
      end
    end
  end

  class Label < SuperClass
  end

  class List < SuperClass
    def create_j data
      javax.swing.JList.new data.to_java
    end
  end

  class Panel < SuperClass
  end

  class RadioButton < SuperClass
    def process_block &block
      @j.add_action_listener &block
    end
  end

  class ScrollPane < SuperClass
    def add thing
      @j.viewport_view = @child = thing
    end

    def return_value
      [self, @child]
    end
  end

  class TabbedPane < SuperClass
    def tab title, &block
      instance_eval &block
    end
  end

  class Table < SuperClass
  end

  class TextArea < SuperClass
  end

  class Timer < SuperClass
    def parent= parent ; end  # parent is ignored

    def create_j duration=0
      javax.swing.Timer.new duration, nil
    end

    def post_init ; end  # don't add to parent

    def process_block &block
      @j.add_action_listener &block
    end

    def post_block
      @j.start
    end
  end

  def self.method_missing name, *args, &block
    if (const = SwingDSL::const_get(SwingDSL::constize name) rescue nil)
      SwingDSL::instantiate_component const, nil, args, &block
    else
      super
    end
  end

end
