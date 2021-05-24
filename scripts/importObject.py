import bpy
import os.path
import time
import json
import mathutils

file_path_obj = '/Users/janjimenezserra/Desktop/dissertation/3DCut&Paste/scans/scan.obj'
file_path_coords = '/Users/janjimenezserra/Desktop/dissertation/3DCut&Paste/scans/coordinates.json'

pasted = False
def checkPaste():
    global file_path 
    global pasted
    if os.path.isfile(file_path_obj) and not(pasted):
        imported_object = bpy.ops.import_scene.obj(filepath=file_path_obj)
        obj_object = bpy.context.selected_objects[0] 
        print('Imported name: ', obj_object.name)
        # store the current location
        loc = obj_object.location

        '''
        # read coordinates 
        with open(file_path_coords) as json_file:
            coordinates = json.load(json_file)
            
        # adjustment values
        (x,y,z) = (coordinates['x'],coordinates['y'],0.0)

        # adding adjustment values to the property
        obj_object.location = loc + mathutils.Vector((x,y,z))
        '''
        
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
        pasted = True

    return 1.0

bpy.app.timers.register(checkPaste)