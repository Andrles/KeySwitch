import Carbon
import Foundation
let filters: [CFString: Any] = [kTISPropertyInputSourceCategory:kTISCategoryKeyboardInputSource!,kTISPropertyInputSourceIsSelectCapable:true]
let sources=TISCreateInputSourceList(filters as CFDictionary,false).takeRetainedValue() as! [TISInputSource]
let keys: [(UInt16,String)] = [(50,"`"),(33,"["),(30,"]"),(41,";"),(39,"'"),(43,","),(47,"."),(42,"\\"),(18,"1"),(19,"2"),(20,"3"),(21,"4"),(23,"5"),(22,"6"),(26,"7"),(28,"8"),(25,"9"),(29,"0")]
for source in sources {
 guard let ptr=TISGetInputSourceProperty(source,kTISPropertyInputSourceID) else {continue}
 let id=Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
 guard id.lowercased().contains("russian") || id.contains("US") || id.contains("ABC") else {continue}
 print(id)
 guard let dp=TISGetInputSourceProperty(source,kTISPropertyUnicodeKeyLayoutData) else {continue}
 let data=Unmanaged<CFData>.fromOpaque(dp).takeUnretainedValue()
 let layout=UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to:UCKeyboardLayout.self)
 for (key,label) in keys {
  var values:[String]=[]
  for modifiers in [UInt32(0),UInt32(shiftKey >> 8)] {
   var state:UInt32=0, count=0;var buffer=[UniChar](repeating:0,count:8)
   let status=UCKeyTranslate(layout,key,UInt16(kUCKeyActionDown),modifiers,UInt32(LMGetKbdType()),OptionBits(kUCKeyTranslateNoDeadKeysMask),&state,8,&count,&buffer)
   values.append(status==noErr ? String(utf16CodeUnits:buffer,count:count):"ERROR")
  }
  print("\(label) => \(values)")
 }
}
