library preprocessor;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as Math;

import 'package:mutable_string/mutable_string.dart';
import 'package:multi_reg_exp/multi_reg_exp.dart';

class Preprocessor{
  String _type;
  Function _pathResolver;
  MultiRegExp _multiRegExp;
  
  static final List<String> types = [
      'js', 'php', 'dart',
      'css', 'less', 'styl', 'scss',
    ];
  
  static final List<String> singleLinesSupportedTypes = [
      'js', 'php', 'dart',
      'less', 'styl', 'scss'
  ];
  
  static final int errorSourceAhead = 50;
  static final RegExp regExpIfThen = new RegExp(r'^(.*) then (.*)$');
  
  Preprocessor(String this._type,[ Function this._pathResolver ]){
    var EXPR_INSTRUCTIONS = '(include(?:Once)?|ifn?def|ifelse|if|\/if|endif|else|el(?:se)?if|eval|value|val|setbasedir)';
    
    var multilineRegExp = new RegExp(r'(^[ \t]*)?\/\*[ ]*#[ ]*' + EXPR_INSTRUCTIONS + r'([^\*]*)[ ]*\*\/', multiLine:true);
    var singlelineRegExp = new RegExp(r'(^[ \t]*)(?:\/\/)?#' + EXPR_INSTRUCTIONS + r'(.*)$', multiLine:true);

    Set<RegExp> regExps = new Set();
    regExps.add(multilineRegExp);
    if(singleLinesSupportedTypes.contains(_type)) regExps.add(singlelineRegExp);
    if(this._type == 'js') regExps.add(new RegExp(r'''(^[ \t]*)?(include(?:Once)?)\('([^\)]*)'\)'''));
    
    this._multiRegExp = new MultiRegExp.fromIterable(regExps);
  }
  
  static indent(String str, String indent){
    return str.split("\n").map((line) => indent + line).join("\n");
  }
  // TODO : process String instead of data. lines by lines. For multi lines things like if/else/elseif, we know if they should be included or not because we know if the condition is valid.
  Future<String> process(Map<String,dynamic> defines,String data){
    MutableString mutableData = new MutableString(data);
    
    Completer<String> completerPreprocessor = new Completer();
    Queue stack = new Queue(); // Queue is too sophisticated
    
    Future.forEach(mutableData.allMatchesFromMultiRegExp(this._multiRegExp),(MutableStringMatch match){
      var completer = new Completer<String>();
      String indent = match[1], instruction=match[2], content=match[3].trim();
      //print('Preprocessor, match: '+match[0]+'; instruction = '+ instruction + ', content = '+content+'; string='+mutableData.string);
      
      switch (instruction) {
        case 'eval':
          throw new Exception('instruction "eval" is not supported');
          break;
        case 'value': case 'val':
          String include = defines[content].toString();
          
          int removeAfterLength = 0;
          String first2=match.input.length >= match.end +2 ? match.input.substring(match.end,match.end+2) : null;
          if(first2 != null && first2=='0 ') removeAfterLength = 2;
          else if(first2 != null && ['0;','0,','0)','0.','0+','0-'].contains(first2)) removeAfterLength = 1;
          else if(first2 != null && first2=="''") removeAfterLength = 2;
          else if(match.input.length >= match.end +5 && match.input.substring(match.end,match.end+5)=='false') removeAfterLength = 5;
          else if(match.input.length >= match.end +4 && match.input.substring(match.end,match.end+4)=='true') removeAfterLength = 4;
          
          match.replacePart(match.start, match.end + removeAfterLength, include);
          completer.complete();
          break;
         
        case 'ifdef': case 'ifndef': case 'if': case 'ifelse':
          var include;
          if (instruction=='ifdef') include = defines.containsKey(content);//!!defines[match2[2]];
          else if (instruction=='ifndef') include = !defines.containsKey(content);//!defines[match2[2]];
          else if (instruction=='ifelse') include = defines[content] ? 1 : 2;
          else{
            Match ifThenMatch = regExpIfThen.firstMatch(content);
            if(ifThenMatch != null){
              include = defines[ifThenMatch[1]] ? ifThenMatch[2] : '';
              match.replacePart(match.start, match.end, include);
              completer.complete();
              break;
            }else if(content.endsWith('=>')){ // if var => : then until the end of the line
              content = content.substring(0, content.length-2).trim();
              if(defines[content])
                match.replacePart(match.start,match.end);
              else
                match.replacePart(match.start,match.input.indexOf("\n",match.end));
            }else{
              if(content[0]=='!') include = !defines[content.substring(1).trim()];
              else include = defines[content];
            }
          }
          
          stack.add({ "include": include, "start": match.start, "end": match.end });
          completer.complete();
          break;
        
        case '/if': case 'endif': case 'else': case 'elif': case 'elseif':
          if (stack.length == 0)
            throw new Exception("Unexpected #"+instruction+": "+match.input.substring(match.start, Math.min(match.start + errorSourceAhead,match.input.length))+"...");
          
          var before = stack.removeFirst();
          var include = match.input.substring(before['end'], match.start);
          if(before['include'] == 1 || before['include'] == 2){
            if(include[0]=='(' && include.substring(include.length-1)==')') include = include.substring(1,include.length-1);
            include = include.split('||');
            if(include.length != 2) return completer.completeError(new Exception('ifelse : '+include.length+' != 2 : '+include.join('||')));
            include = include[before['include']-1];
          }else if(!before['include']) include='';
          match.replacePart(before['start'], match.end, include);
          if (instruction == "else" || instruction == "elif" || instruction == "elseif") {
            if(instruction=='else') include=!before['include'];
            else{
              if(content[0]=='!') include = !defines[content.substring(1).trim()];
              else include = defines[content];
            }
            stack.add({ "include": !before["include"], "start": match.lastIndex, "lastIndex": match.lastIndex });
          }
          completer.complete();
          break;

        case 'include': case 'includeOnce':
          /*if(content.slice(-1) === '/') content += sysPath.basename(content) + '.js';
          else if(content.slice(-3) !== '.js') content += '.js';
          if(content.substr(0,1) !== '/') content = dirname + content;
          var path = (pathResolver||fs.realpathSync)(content);
          if(instruction === 'includeOnce' && includedFiles.indexOf(path) !== -1){
            data = data.substring(0, match.index) + '' + data.substring(EXPR.lastIndex + removeAfterLength);
            onEnd();
          }else{
            includedFiles.push(path);
            fs.readFile(path,function(err,content){
              if(err) return onEnd(err);
              module.exports(defines, content, baseDir, includedFiles,function(err,include){
                if(err) return onEnd(err);
                data = data.substring(0, match.index) + content + data.substring(EXPR.lastIndex + removeAfterLength);
                onEnd();
              });
            });
          }*/
          completer.complete();
          break;
          
        default:
          completer.complete();
      }
      
      return completer.future;
    }).then((_){
        completerPreprocessor.complete(mutableData.string);
      }, onError: completerPreprocessor.completeError );
    return completerPreprocessor.future;
  }
}

main(){
	return (String type,Function pathResolver) => new Preprocessor(type,pathResolver);
}