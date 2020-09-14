unit mungo.textfile.maki.sourceeditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls,

  mungo.intf.filepointer,

  SynHighlighterPosition, SynEditHighlighter,
  DateUtils, Generics.Collections, SynFacilHighlighter, SynFacilBasic,

  mungo.components.colors, st.storage,
  mungo.textfile.sourceeditor, mungo.textfile.messages;

type

  { TSourceEditorMaki }

  TSourceEditorMaki = class ( TSourceEditor )
    function CreateHighlighter: TSynFacilSyn;
    constructor Create(ARootControl: TObject; AFileInfo: TFilePointer); override; overload;
    class function FileMatch(AFileInfo: TFilePointer): Boolean; override;
    procedure UpdateSyntaxTree; override;
  end;

implementation

uses
  mungo.intf.editor,
  mungo.textfile.sourcetree,
  maki.tokenizer, maki.scanner, maki.parser, maki.node;

{ TSourceEditorMaki }

function TSourceEditorMaki.CreateHighlighter: TSynFacilSyn;
var
  outp, nd, glsl, if_, str: TFaSynBlock;
begin
  Result:= TSynFacilSyn.Create( Control as TComponent );

  Result.ClearMethodTables;
  Result.ClearSpecials;
  Result.DefTokIdentif('[$A-Za-z_]', '[A-Za-z0-9_]*');

  Result.AddKeyword('node');
  Result.AddKeyword('lib');

  Result.AddKeyword('input');
  Result.AddKeyword('output');
  Result.AddKeyword('select');

  Result.AddKeyword('ifdef');
  Result.AddKeyword('ifconn');
  Result.AddKeyword('else');
  Result.AddKeyword('endif');
  Result.AddKeyword('endnode');
  Result.AddKeyword('endoutput');

  //nd:= Result.AddSection( '---' );
//  outp:= Result.AddSection('output', True, nd );

  nd:= Result.AddBlock('node', 'endnode', True, nil );
  outp:= Result.AddBlock('output', 'endoutput', True, nd );
  Result.AddBlock('ifdef', 'endif', True, nil );
  Result.AddBlock('ifconn', 'endif', True, nil );

  str:= Result.AddBlock( '''', '''', True, outp );

  //glsl:= Result.AddBlock('''{glsl}','''', True, outp );

//  Result.DefTokDelim('''','''', Result.tnString, tdMulLin, True );

  Result.DefTokDelim('#', '', Result.tnComment);
  Result.Rebuild;
end;

constructor TSourceEditorMaki.Create(ARootControl: TObject; AFileInfo: TFilePointer);
begin
  inherited Create(ARootControl, AFileInfo);
  Editor.Highlighter:= CreateHighlighter;

  Editor.Gutter.Color:= White;
  Editor.Color:= White;
//  Editor.BracketMatchColor:= Blue800;
  with ( TSynFacilSyn( Editor.Highlighter )) do begin
    tkNumber.Foreground:= Blue600;
    tkString.Foreground:= BlueGray600;
    tkSymbol.Foreground:= Brown600;
    tkComment.Foreground:= LightGreen600;
  end;
end;

class function TSourceEditorMaki.FileMatch(AFileInfo: TFilePointer): Boolean;
begin
  Result:= inherited;
  if ( Result ) then
    Result:= AFileInfo.Extension = '.maki';
end;

procedure TSourceEditorMaki.UpdateSyntaxTree;
var
  F: TScannerString;
  Tokenizer: TTokenizer;
  Tokens: TTokenStream;
  Parser: TParser;
  ParserResult: TParserResult;
  NodeS: String;
  Node: TNodeType;
  TreeNode, TreeInputOutput: Pointer;
  SocketS: String;
  Socket: TNodeSocketType;
  i: Integer;
  E: TError;
  P: TPoint;
begin
  if ( not Assigned( SourceTreeIntf )) then
    exit;

  inherited UpdateSyntaxTree;

  F:= TScannerString.Create( Editor.Text );

  Tokenizer:= TTokenizer.Create( F );
  Tokens:= Tokenizer.Tokenize;
  Parser:= TParser.Create( Tokens );
  ParserResult:= Parser.Parse( FileInfo.FileName );

  MessageIntf.ClearMessages;

  try
    for NodeS in ParserResult.Module.Types.Map.Keys do begin
      Node:= ParserResult.Module.Types[ NodeS ];
      TreeNode:= SourceTreeIntf.AddNode( nil, ST_SYMBOLS_NODE, Node.Name, Point( 0, 0 ));

      // INPUTS :
      if ( Node.Inputs.Map.Count > 0 ) then begin
        TreeInputOutput:= SourceTreeIntf.AddNode( TreeNode, ST_SYMBOLS_FIELD, 'inputs', Point( 0, 0 ));
        for SocketS in Node.Inputs.Map.Keys do begin
          Socket:= Node.Inputs[ SocketS ];
          SourceTreeIntf.AddNode( TreeInputOutput, ST_SYMBOLS_FIELD, Socket.SocketType.GetTypeName + ' ' + Socket.Name, Point( 0, 0 ));
        end;
      end;

      // OUTPUTS:
      if ( Node.Outputs.Map.Count > 0 ) then begin
        TreeInputOutput:= SourceTreeIntf.AddNode( TreeNode, ST_SYMBOLS_METHOD, 'outputs', Point( 0, 0 ));
        for SocketS in Node.Outputs.Map.Keys do begin
          Socket:= Node.Outputs[ SocketS ];
          SourceTreeIntf.AddNode( TreeInputOutput, ST_SYMBOLS_METHOD, Socket.SocketType.GetTypeName + ' ' + Socket.Name, Point( 0, 0 ));
        end;
      end;

      // LIBS:
      if ( Node.Libs.Map.Count > 0 ) then begin
        TreeInputOutput:= SourceTreeIntf.AddNode( TreeNode, ST_SYMBOLS_LIBRARY, 'libs', Point( 0, 0 ));
        for SocketS in Node.Libs.Map.Keys do begin
          Socket:= Node.Libs[ SocketS ];
          SourceTreeIntf.AddNode( TreeInputOutput, ST_SYMBOLS_LIBRARY, Socket.Name, Point( 0, 0 ));
        end;
      end;
    end;
  except
    On E: Exception do
      MessageIntf.AddMessage( M_SYMBOLS_ERROR, E.Message, Point( 0, 0 ));
  end;

  if ( Assigned( Tokens )) then
    for i:= 0 to Tokens.Errors.Count - 1 do begin
      E:= Tokens.Errors[ i ];
      P:= Tokenizer.Scanner.GetCaretPos( E.StringPos );
      MessageIntf.AddMessage( M_SYMBOLS_ERROR, Format( '[%d, %d] %s', [ P.Y, P.X, E.Message ]), P );
    end;

  if ( Assigned( ParserResult )) then begin
    for i:= 0 to ParserResult.Errors.Count - 1 do begin
      E:= ParserResult.Errors[ i ];
      P:= Tokenizer.Scanner.GetCaretPos( E.StringPos );
      MessageIntf.AddMessage( M_SYMBOLS_ERROR, Format( '[%d, %d] %s', [ P.Y, P.X, E.Message ]), P );
    end;
  end;
  FreeAndNil( Tokenizer );
  FreeAndNil( F );
  FreeAndNil( Tokens );
  FreeAndNil( Parser );
  ParserResult.Module.Free;
  FreeAndNil( ParserResult );
end;

end.

