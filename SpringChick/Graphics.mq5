#include "Graphics.mqh"

void Graphics::DisplayVert(string s, datetime t, double p)
{
    string name = TimeToString(t);
    if(map.ContainsKey(t))
    {
//        Print(__FUNCTION__,"there! ",GetLastError());
        string mapstr;
        map.TryGetValue(t,mapstr);
        string str = mapstr + " " + s;
        map.TrySetValue(t,str);
        ObjectSetString(0,name,OBJPROP_TEXT,str);
    }
    else
    {
        if(!ObjectCreate(0,name,OBJ_TEXT,0,t,p))
            Print(__FUNCTION__,":failed to create object = ",GetLastError());
        else
        {
            s = "     "+s;
            map.Add(t,s);
            ObjectSetString(0,name,OBJPROP_TEXT,s);
            //   ObjectSetString(chart_ID,name,OBJPROP_FONT,"Arial");
            ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
            ObjectSetDouble(0,name,OBJPROP_ANGLE,90);
            ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
            ObjectSetInteger(0,name,OBJPROP_COLOR,clrRed);
            //   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
            ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
            ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
            //   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
            //   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
        }
    }
    ChartRedraw();
    return;
}

void Graphics::DisplyHor(string s, datetime t, double p)
{
}

void Graphics::Clear()
{
    ObjectsDeleteAll(0);
}
