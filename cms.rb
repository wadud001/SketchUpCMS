# Tai Sakuma <sakuma@fnal.gov>
require 'sketchup'

# $LOAD_PATH << '/usr/lib/ruby/1.8/'
$LOAD_PATH.push("/opt/local/lib/ruby/site_ruby/1.8", "/opt/local/lib/ruby/site_ruby/1.8/i686-darwin10", "/opt/local/lib/ruby/site_ruby", "/opt/local/lib/ruby/vendor_ruby/1.8", "/opt/local/lib/ruby/vendor_ruby/1.8/i686-darwin10", "/opt/local/lib/ruby/vendor_ruby", "/opt/local/lib/ruby/1.8", "/opt/local/lib/ruby/1.8/i686-darwin10")
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))

require 'gratr'

require 'ddlcallbacks'
load 'ddlcallbacks.rb'

# require 'solids'
load 'solids.rb'

require 'GeometryManager'

load 'GeometryManager.rb'
load 'EntityDisplayer.rb'
load 'RotationsManager.rb'
load 'SolidsManager.rb'
load 'LogicalPartsManager.rb'
load 'PosPartsManager.rb'
load 'MaterialsManager.rb'

load 'defs.rb'

##____________________________________________________________________________||
def cmsmain

  read_xmlfiles
  draw_gratr_20120317_02

end

##____________________________________________________________________________||
def draw_gratr_20120317_02
  def create_array_to_draw graph

    # GRATR::Digraph
    topName = :"cms:CMSE"
    graphFromCMSE = subgraph_from(graph, topName)

    nameDepthList = [ {:name => :"tob:TOBLayer0", :depth => 2},
                      {:name => :"tob:TOBLayer1", :depth => 2},
                      {:name => :"tob:TOBLayer2", :depth => 2},
                      {:name => :"tob:TOBLayer3", :depth => 2},
                      {:name => :"tob:TOBLayer4", :depth => 2},
                      {:name => :"tob:TOBLayer5", :depth => 2},
                    ]

    names = nameDepthList.collect { |e| e[:name] }
    graphFromCMSEToNames = subgraph_from_to(graphFromCMSE, topName, names)

    graphFromNames = GRATR::Digraph.new
    nameDepthList.each do |e|
      graphFromNames = graphFromNames + subgraph_from_depth(graphFromCMSE, e[:name], e[:depth])
    end

    graphToDraw = graphFromCMSEToNames + graphFromNames

    # e.g. [:"cms:CMSE", :"tracker:Tracker", :"tob:TOB", .. ]
    toDrawNames = graphToDraw.size > 0 ? graphToDraw.topsort(topName) : [topName]

    toDrawNames
  end

  # all PosParts in the XML file
  graphAll = GRATR::Digraph.new
  $posPartsManager.parts.each { |pp| graphAll.add_edge!(pp.parentName, pp.childName) }

  arrayToDraw = create_array_to_draw graphAll
  draw_array graphAll, arrayToDraw.reverse
end

##____________________________________________________________________________||
def draw_array graph, arrayToDraw

  Sketchup.active_model.definitions.purge_unused
  start_time = Time.now
  Sketchup.active_model.start_operation("Draw CMS", true)

  arrayToDraw.each do |parent|
    children = graph.neighborhood(parent, :out)
    children = children.select { |e| arrayToDraw.include?(e) }
    children.each do |child|
      posParts = $posPartsManager.getByParentChild(parent, child)
      posParts.each do |posPart|
        # puts "  exec posPart #{posPart.parentName} - #{posPart.childName}"
        posPart.exec
      end
    end
  end

  arrayToDraw.each do |v|
    logicalPart = $logicalPartsManager.get(v)
    next if logicalPart.children.size > 0 and logicalPart.materialName.to_s =~ /Air$/
    next if logicalPart.children.size > 0 and logicalPart.materialName.to_s =~ /free_space$/
    logicalPart.placeSolid()
  end

  arrayToDraw.each do |v|
    logicalPart = $logicalPartsManager.get(v)
    logicalPart.define()
  end

  # lp = $logicalPartsManager.get("cms:CMSE".to_sym)
  lp = $logicalPartsManager.get("tob:TOB".to_sym)
  definition = lp.definition
  if definition
    entities = Sketchup.active_model.entities
    transform = Geom::Transformation.new(Geom::Point3d.new(0, 0, 15.m))
    solidInstance = entities.add_instance definition, transform
  end

  Sketchup.active_model.commit_operation
  end_time = Time.now
  puts "Time elapsed #{(end_time - start_time)*1000} milliseconds"


end

##____________________________________________________________________________||
def read_xmlfiles
  topDir = File.expand_path(File.dirname(__FILE__)) + '/'
  xmlfileListTest = [
        # 'fred_01.xml'
        'tob_03.xml'
                    ]

  xmlfileList = xmlfileListTest

  xmlfileList.map! {|f| f = topDir + f }

  p xmlfileList

  geometryManager = buildGeometryManager()
  callBacks = buildDDLCallBacks(geometryManager)
  readXMLFiles(xmlfileList, callBacks, geometryManager)
end

##____________________________________________________________________________||
def buildGeometryManager
  $materialsManager = MaterialsManager.new
  $rotationsManager = RotationsManager.new
  $geometryManager = GeometryManager.new
  $solidsManager = SolidsManager.new
  $logicalPartsManager = LogicalPartsManager.new
  $posPartsManager = PosPartsManager.new

  $solidsManager.entityDisplayer = EntityDisplayer.new('solids', 100.m, 0, 0)
  $logicalPartsManager.entityDisplayer = EntityDisplayer.new('logicalParts', -100.m, 0, 0)

  geometryManager = $geometryManager
  geometryManager.materialsManager = $materialsManager
  geometryManager.rotationsManager = $rotationsManager
  geometryManager.solidsManager = $solidsManager
  geometryManager.logicalPartsManager = $logicalPartsManager
  geometryManager.posPartsManager = $posPartsManager

  $materialsManager.geometryManager = geometryManager
  $rotationsManager.geometryManager = geometryManager
  $solidsManager.geometryManager = geometryManager
  $logicalPartsManager.geometryManager = geometryManager
  $posPartsManager.geometryManager = geometryManager

  geometryManager
end

##____________________________________________________________________________||

cmsmain
