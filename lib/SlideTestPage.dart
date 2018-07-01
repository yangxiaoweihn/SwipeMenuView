
import 'package:flutter/material.dart';
import 'package:justjoke/src/ws/dyt/justjoke/libs/widget/SlideMenuWidget.dart';

class SlideTestPage extends StatefulWidget {

    static void toHere(BuildContext context) {

        Navigator.push(context, new MaterialPageRoute(builder: (context) => new SlideTestPage()));
    }

    @override
    _SlideTestPageState createState() => new _SlideTestPageState();
}

class _SlideTestPageState extends State<SlideTestPage> {
    @override
    Widget build(BuildContext context) {
        return new Scaffold(

	    appBar: new AppBar(),

	    body: this._body(),
	);
    }

    Widget _body() {


        return new ListView.builder(itemBuilder: (context, index) {

            return this._item(index);
	}, itemCount: 25,);
    }

    Widget _item(int index) {

        Widget menus = new Container(
	    color: Colors.blue,
	    width: 80.0,
	    key: new GlobalObjectKey('key-item-menus: $index'),
	    alignment: Alignment.center,
	    child: new Text('mark'),
	);

        return new SlideMenuWidget(
	    key: new GlobalObjectKey('key-item: $index'),
	    direction: DismissDirection.endToStart,
	    background: new Container(
//		key: new GlobalObjectKey('key-item-background: $index'),
		color: Colors.red,
		width: 100.0,
		height: double.infinity,
	    ),
	    secondaryBackground: menus,
	    menusWidth: 80.0,
	    child: new Container(
		color: Colors.grey,
		child: new ListTile(
		    title: new Text('title -> index: $index'),
		),
	    ),
	);
    }
}
