using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ShowFPS : MonoBehaviour
{
    public float showTime = 1f;

    private int count = 0;
    private float deltaTime = 0f;

    private void OnGUI()
    {
        GUI.skin.label.normal.textColor = new Color(1, 0, 0, 1.0f);
        // 后面的color为 RGBA的格式，支持alpha，取值范围为浮点数： 0 - 1.0.
        GUI.skin.label.fontSize = 20;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        GUI.Label(new Rect(25, 25, 1080, 30), strFpsInfo);
    }

    string strFpsInfo;

    void Update()
    {
        count++;
        deltaTime += Time.deltaTime;
        if (deltaTime >= showTime)
        {
            float fps = count / deltaTime;
            float milliSecond = deltaTime * 1000 / count;
            strFpsInfo = string.Format(" 当前每帧渲染间隔：{0:0.0} ms ({1:0.} 帧每秒)", milliSecond, fps);
            
            count = 0;
            deltaTime = 0f;
        }
    }
}
